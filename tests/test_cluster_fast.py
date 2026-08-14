import sys
from project_paths import TOOLS_ROOT
sys.path.insert(0, str(TOOLS_ROOT))
try:
    import vtk
except ModuleNotFoundError:
    print('SKIP VTK-only mesh-processing test (VTK is not a runtime dependency)')
    raise SystemExit(0)
from static_batch_processor import cluster_fast

def make_sphere():
    s=vtk.vtkSphereSource(); s.SetThetaResolution(64); s.SetPhiResolution(64); s.Update()
    tri=vtk.vtkTriangleFilter(); tri.SetInputData(s.GetOutput()); tri.Update()
    p=vtk.vtkPolyData(); p.DeepCopy(tri.GetOutput()); return p

p=make_sphere()
out,n=cluster_fast(p, 1200, 8, 80)
c=out.GetNumberOfCells()
assert 700 <= c <= 1800, (c,n)
assert 8 <= n <= 80
print('PASS',c,n)
