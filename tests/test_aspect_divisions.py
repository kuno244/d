import sys
from project_paths import TOOLS_ROOT
sys.path.insert(0, str(TOOLS_ROOT))
from static_batch_processor import aspect_divisions
assert aspect_divisions((0.7,1.9,0.7), 100) == (37,100,37)
assert aspect_divisions((1.9,1.9,1.9), 64) == (64,64,64)
print('PASS')
