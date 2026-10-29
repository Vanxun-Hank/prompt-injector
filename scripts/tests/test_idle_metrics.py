import importlib.util
import unittest
from pathlib import Path
spec=importlib.util.spec_from_file_location('idle',Path(__file__).parents[1]/'measure-idle.py')
idle=importlib.util.module_from_spec(spec);spec.loader.exec_module(idle)

class IdleMetricsTests(unittest.TestCase):
    def testPSCPUTimeFormats(self):
        self.assertEqual(idle.cpu_seconds('0:00.02'),.02)
        self.assertEqual(idle.cpu_seconds('01:02:03.45'),3723.45)
        self.assertEqual(idle.cpu_seconds('2-01:02:03.45'),176523.45)
        with self.assertRaises(ValueError): idle.cpu_seconds('nan')
    def testCPUUsesDeltaNotLifetimePercentageAndRSSIsMiB(self):
        result=idle.summarize([{'monotonic':100,'cpuSeconds':50,'rssKiB':102400},{'monotonic':130,'cpuSeconds':50.3,'rssKiB':104448}])
        self.assertAlmostEqual(result['averageCPUPercentOfOneCore'],1)
        self.assertEqual(result['rssMiB']['median'],101)
        with self.assertRaises(ValueError): idle.summarize([{'monotonic':100,'cpuSeconds':50,'rssKiB':1},{'monotonic':130,'cpuSeconds':0,'rssKiB':1}])
