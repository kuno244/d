try:
    import vtk
except ModuleNotFoundError:
    vtk = None

def aspect_divisions(dims, max_divisions):
    dims=[max(float(x),1e-9) for x in dims]
    m=max(dims); n=max(2,int(max_divisions))
    return tuple(max(2,int(round(n*(d/m)))) for d in dims)


def _cluster(poly, n):
    if vtk is None:
        raise RuntimeError("VTK is required for mesh clustering")
    q=vtk.vtkQuadricClustering()
    q.SetInputData(poly)
    b=poly.GetBounds(); dims=(b[1]-b[0], b[3]-b[2], b[5]-b[4])
    dx,dy,dz=aspect_divisions(dims,n)
    q.SetNumberOfXDivisions(dx); q.SetNumberOfYDivisions(dy); q.SetNumberOfZDivisions(dz)
    q.UseInputPointsOn(); q.CopyCellDataOn(); q.Update()
    out=vtk.vtkPolyData(); out.DeepCopy(q.GetOutput())
    return out

def cluster_fast(poly, target, low=8, high=160, max_steps=9):
    target=max(1,int(target)); low=max(2,int(low)); high=max(low,int(high))
    cache={}
    def eval_n(n):
        n=int(n)
        if n not in cache:
            o=_cluster(poly,n); cache[n]=(o,o.GetNumberOfCells())
        return cache[n]
    best=None
    lo,hi=low,high
    for _ in range(max_steps):
        if lo>hi: break
        mid=(lo+hi)//2
        o,c=eval_n(mid)
        if best is None or abs(c-target)<abs(best[2]-target): best=(o,mid,c)
        if c<target: lo=mid+1
        elif c>target: hi=mid-1
        else: break
    # Only probe the converged neighborhood; probing the original high endpoint can allocate
    # an enormous isotropic grid for no benefit once binary search has bracketed the target.
    for n in {max(low,min(high,lo)), max(low,min(high,hi))}:
        o,c=eval_n(n)
        if best is None or abs(c-target)<abs(best[2]-target): best=(o,n,c)
    return best[0],best[1]
