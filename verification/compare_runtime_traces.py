from pathlib import Path
import re,json,difflib,argparse

def normalize(s):
 start=s.index('local response = game:HttpGet(')
 end=s.index('\x00ENVLOG-STRINGS',start) if '\x00ENVLOG-STRINGS' in s[start:] else s.index('\x00ENVLOG-END',start)
 s=s[start:end]
 s=re.sub(r'^\s*--@\d+.*\n','',s,flags=re.M)
 # Devirtualization removes nested VM error wrappers and changes line numbers.
 # Preserve the actual error text, location in the trace and all operations.
 s=re.sub(r'((?:Luraph )?Script:\d+: )+','Script:LINE: ',s)
 for name in ['connection','descendant','Folder','HttpService','RunService']:
  s=re.sub(r'\b'+name+r'\d*\b',name,s)
 return re.sub(r'local RunService = game:GetService\("RunService"\)\n','',s)

if __name__=='__main__':
 ap=argparse.ArgumentParser();ap.add_argument('old',type=Path);ap.add_argument('new',type=Path);ap.add_argument('report',type=Path);args=ap.parse_args()
 x=normalize(args.old.read_text(errors='replace'));y=normalize(args.new.read_text(errors='replace'))
 diff=''.join(difflib.unified_diff(x.splitlines(True),y.splitlines(True)))
 args.report.with_suffix('.diff.txt').write_text(diff)
 report={'equal_after_documented_normalization':x==y,'old_lines':len(x.splitlines()),'new_lines':len(y.splitlines()),'normalization':'Drop proto annotations; normalize VM error wrappers/line numbers and logger-generated connection, descendant, Folder, HttpService, RunService suffixes; omit a redundant RunService local declaration. All operations and error messages retained.'}
 args.report.write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2))
