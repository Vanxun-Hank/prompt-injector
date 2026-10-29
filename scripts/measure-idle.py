#!/usr/bin/env python3
"""Measure cumulative CPU deltas and RSS for an already running app; does not manipulate its UI."""
import argparse
import datetime
import json
import math
import statistics
import subprocess
import time
from pathlib import Path


def cpu_seconds(value):
    days, clock = (value.split('-', 1) if '-' in value else ('0', value))
    parts = clock.split(':')
    if len(parts) == 2:
        hours, minutes, seconds = 0, int(parts[0]), float(parts[1])
    elif len(parts) == 3:
        hours, minutes, seconds = int(parts[0]), int(parts[1]), float(parts[2])
    else:
        raise ValueError('Invalid ps CPU time')
    result = int(days)*86400 + hours*3600 + minutes*60 + seconds
    if result < 0 or not math.isfinite(result):
        raise ValueError('Invalid CPU time')
    return result


def summarize(samples):
    if len(samples) < 2:
        raise ValueError('At least two samples required')
    elapsed = samples[-1]['monotonic'] - samples[0]['monotonic']
    cpu = samples[-1]['cpuSeconds'] - samples[0]['cpuSeconds']
    if elapsed <= 0 or cpu < 0:
        raise ValueError('Process restarted or clock invalid')
    rss = [s['rssKiB']/1024 for s in samples]
    return {'sampleCount':len(samples), 'durationSeconds':elapsed,
            'cpuSecondsUsed':cpu, 'averageCPUPercentOfOneCore':cpu/elapsed*100,
            'rssMiB':{'min':min(rss),'median':statistics.median(rss),'max':max(rss)},
            'notes':'RSS is resident memory, not Activity Monitor memory footprint. CPU uses cumulative process time (ps precision 0.01s); 100% means one core.'}


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--pid',type=int,required=True)
    parser.add_argument('--seconds',type=int,default=30)
    parser.add_argument('--label',required=True,choices=['hidden-idle','visible-idle'])
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    if not 10 <= args.seconds <= 60: parser.error('--seconds must be 10..60')
    identity=subprocess.check_output(['ps','-p',str(args.pid),'-o','lstart=','-o','comm='],text=True).strip()
    if not identity.endswith('/PromptInjector'): parser.error('PID is not PromptInjector')
    samples=[]
    started=datetime.datetime.now(datetime.timezone.utc).isoformat()
    for i in range(args.seconds+1):
        line=subprocess.check_output(['ps','-p',str(args.pid),'-o','time=','-o','rss='],text=True).strip().split()
        if len(line)!=2: raise RuntimeError('Process disappeared')
        samples.append({'monotonic':time.monotonic(),'cpuSeconds':cpu_seconds(line[0]),'rssKiB':int(line[1])})
        if i<args.seconds: time.sleep(1)
    after=subprocess.check_output(['ps','-p',str(args.pid),'-o','lstart=','-o','comm='],text=True).strip()
    if after!=identity: raise RuntimeError('Process identity changed during sampling')
    result={'pid':args.pid,'label':args.label,'startedAt':started,'finishedAt':datetime.datetime.now(datetime.timezone.utc).isoformat(),'summary':summarize(samples),'samples':samples}
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result['summary'],indent=2))

if __name__=='__main__': main()
