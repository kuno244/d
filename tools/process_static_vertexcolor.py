import os,sys,json,time,shutil
from pathlib import Path
import numpy as np, vtk, trimesh
from vtk.util.numpy_support import vtk_to_numpy,numpy_to_vtk
BASE=str(Path(__file__).resolve().parents[1])

def deep(o):
    if isinstance(o,vtk.vtkPolyData): return o
    if isinstance(o,vtk.vtkMultiBlockDataSet):
        for i in range(o.GetNumberOfBlocks()):
            b=o.GetBlock(i)
            if b:
                z=deep(b)
                if z is not None:return z

def load_colored_poly(src):
    r=vtk.vtkGLTFReader();r.SetFileName(src);r.Update();p=deep(r.GetOutputDataObject(0));tr=vtk.vtkTriangleFilter();tr.SetInputData(p);tr.Update();p=vtk.vtkPolyData();p.DeepCopy(tr.GetOutput())
    uv=vtk_to_numpy(p.GetPointData().GetArray('TEXCOORD_0')).astype(np.float64)
    sc=trimesh.load(src,force='scene',process=False);g=list(sc.geometry.values())[0]; img=np.asarray(g.visual.material.baseColorTexture.convert('RGB'))
    # VTK glTF V is opposite trimesh's V. PIL top-origin row maps directly from VTK V.
    u=np.mod(uv[:,0],1.0);v=np.mod(uv[:,1],1.0)
    x=np.clip(np.rint(u*(img.shape[1]-1)).astype(np.int64),0,img.shape[1]-1); y=np.clip(np.rint(v*(img.shape[0]-1)).astype(np.int64),0,img.shape[0]-1)
    colors=img[y,x].astype(np.uint8)
    arr=numpy_to_vtk(colors,deep=True,array_type=vtk.VTK_UNSIGNED_CHAR);arr.SetName('COLOR_0');arr.SetNumberOfComponents(3);p.GetPointData().SetScalars(arr)
    return p, g

def cluster(poly,target):
    from static_batch_processor import cluster_fast
    return cluster_fast(poly, target, 8, 160, 9)

def to_mesh(o):
    pts=vtk_to_numpy(o.GetPoints().GetData()).astype(np.float64);conn=vtk_to_numpy(o.GetPolys().GetConnectivityArray()).astype(np.int64);offs=vtk_to_numpy(o.GetPolys().GetOffsetsArray());assert np.all(np.diff(offs)==3);faces=conn.reshape(-1,3)
    col=vtk_to_numpy(o.GetPointData().GetScalars()); col=np.clip(col,0,255).astype(np.uint8); rgba=np.concatenate([col[:,:3],np.full((len(col),1),255,dtype=np.uint8)],axis=1)
    m=trimesh.Trimesh(vertices=pts,faces=faces,vertex_colors=rgba,process=False);m.remove_unreferenced_vertices();return m

def process(asset,folder,targets):
    src=f'{BASE}/assets/source/{asset}.glb'; outd=f'{BASE}/assets/mobile/{folder}/{asset}';procd=f'{BASE}/assets/processed/{asset}';os.makedirs(outd,exist_ok=True);os.makedirs(procd,exist_ok=True)
    clean=f'{procd}/{asset}_clean.glb';shutil.copy2(src,clean)
    p,g=load_colored_poly(src);raw=p.GetNumberOfCells();res={}
    for tier,target in targets.items():
        t=time.time();o,n=cluster(p,int(target));m=to_mesh(o);out=f'{outd}/{asset}_{tier.lower()}.glb';trimesh.Scene(m).export(out,file_type='glb')
        res[tier]={'input_triangles':raw,'triangles':len(m.faces),'vertices':len(m.vertices),'target_triangles':int(target),'cluster_divisions':n,'texture_sizes':{},'texture_mode':'base_color_baked_to_vertex_colors','embedded_texture_count':0,'file_size_bytes':os.path.getsize(out),'elapsed_seconds':round(time.time()-t,2),'path':os.path.relpath(out,BASE)}; print(tier,res[tier],flush=True)
    bounds=np.asarray(g.bounds);dims=(bounds[1]-bounds[0]).tolist();center=((bounds[0]+bounds[1])/2).tolist();collision={'strategy':'simple_box','primitive':True,'center':center,'size':dims,'collision_mesh_triangles':0}
    json.dump(collision,open(f'{procd}/collision.json','w'),indent=2)
    rep={'asset_id':asset,'raw_file':os.path.relpath(src,BASE),'clean_file':os.path.relpath(clean,BASE),'raw_size_bytes':os.path.getsize(src),'source_texture_sizes':{'base_color':[4096,4096],'metallic_roughness':[2048,2048],'normal':[4096,4096]},'lods':res,'collision':collision,'decimator':'vtkQuadricClustering with Base Color baked to vertex colors','quality_scope':'static distant world/decor only; normal/metallic texture detail intentionally omitted in far mobile LODs'}
    json.dump(rep,open(f'{procd}/processing_report_static_vertexcolor.json','w'),indent=2)
    print('COMPLETE',asset)
if __name__=='__main__': process(sys.argv[1],sys.argv[2],json.loads(sys.argv[3]))
