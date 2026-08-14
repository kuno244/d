import sys
from project_paths import TOOLS_ROOT
sys.path.insert(0,str(TOOLS_ROOT))
import static_batch_processor as m
seen=[]
class O:
    def __init__(self,c): self.c=c
    def GetNumberOfCells(self): return self.c
old=m._cluster
try:
    def fake(poly,n):
        seen.append(n)
        return O(n*1000)
    m._cluster=fake
    out,n=m.cluster_fast(object(), 50000, 8, 160, 9)
    assert n == 50, (n,seen)
    assert 160 not in seen, seen
finally:
    m._cluster=old
print('PASS')
