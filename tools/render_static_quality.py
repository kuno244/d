import os,math,json,sys
from pathlib import Path
import vtk
from PIL import Image,ImageDraw
ROOT=str(Path(__file__).resolve().parents[1])
DEV02='/mnt/data/crownfront_dev03_work/dev02/previews'
OUT=f'{ROOT}/reports/quality_previews'; os.makedirs(OUT,exist_ok=True)
reg=json.load(open(f'{ROOT}/registry/asset_registry.json'))

def render(path,out,size=320):
    ren=vtk.vtkRenderer(); ren.SetBackground(0.1,0.1,0.12); ren.SetBackground2(0.18,0.18,0.21); ren.GradientBackgroundOn()
    win=vtk.vtkRenderWindow(); win.SetOffScreenRendering(1); win.SetSize(size,size); win.AddRenderer(ren)
    imp=vtk.vtkGLTFImporter(); imp.SetFileName(path); imp.SetRenderWindow(win); imp.Update()
    b=ren.ComputeVisiblePropBounds(); xmin,xmax,ymin,ymax,zmin,zmax=b;c=((xmin+xmax)/2,(ymin+ymax)/2,(zmin+zmax)/2);rad=max(xmax-xmin,ymax-ymin,zmax-zmin)/2
    u=(2**-0.5,0,2**-0.5); dist=max(rad*3.4,1e-3)
    cam=ren.GetActiveCamera();cam.SetFocalPoint(*c);cam.SetPosition(c[0]+u[0]*dist,c[1],c[2]+u[2]*dist);cam.SetViewUp(0,1,0);cam.SetViewAngle(28);ren.ResetCameraClippingRange();win.Render()
    w=vtk.vtkWindowToImageFilter();w.SetInput(win);w.SetInputBufferTypeToRGB();w.ReadFrontBufferOff();w.Update();wr=vtk.vtkPNGWriter();wr.SetFileName(out);wr.SetInputConnection(w.GetOutputPort());wr.Write();win.Finalize()

def folder_for(a):
    return {'BUILDING':'buildings','WORLD_OBJECT':'world','DECORATION':'decorations'}[a['category']]

static=[a for a in reg['assets'] if a['category'] in ('BUILDING','WORLD_OBJECT','DECORATION')]
rows=[]
for a in static:
    idx=int(a['index']); aid=a['asset_id']; raw=f'{DEV02}/asset_{idx:03d}_threequarter.png'
    folder=folder_for(a); base=f'{ROOT}/assets/mobile/{folder}/{aid}'
    ims=[Image.open(raw).convert('RGB').resize((320,320))]
    for tier in ('lod0','lod1','lod2'):
        p=f'{base}/{aid}_{tier}.glb'; out=f'{OUT}/{aid}_{tier}.png'; render(p,out); ims.append(Image.open(out).convert('RGB'))
    row=Image.new('RGB',(1280,350),(15,15,17)); d=ImageDraw.Draw(row); d.text((8,6),aid,fill='white')
    labels=['RAW','LOD0','LOD1','LOD2']
    for i,(lab,im) in enumerate(zip(labels,ims)):
        row.paste(im,(i*320,30)); d.text((i*320+8,31),lab,fill='white')
    rp=f'{OUT}/{aid}_compare.jpg'; row.save(rp,quality=90); rows.append((aid,row))
for start in range(0,len(rows),7):
    chunk=rows[start:start+7]; sheet=Image.new('RGB',(1280,350*len(chunk)),(8,8,9))
    for j,(aid,row) in enumerate(chunk): sheet.paste(row,(0,j*350))
    out=f'{OUT}/static_quality_{start+1:02d}_{start+len(chunk):02d}.jpg'; sheet.save(out,quality=88); print(out)
