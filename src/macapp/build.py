from pathlib import Path
import plistlib,subprocess,shutil

ROOT=Path(__file__).resolve().parents[2];SRC=ROOT/'src/macapp'
APP=ROOT/'build/财务快照.app'
BIN=APP/'Contents/MacOS';RES=APP/'Contents/Resources';CACHE=SRC/'.cache'
for p in [BIN,RES,CACHE]:p.mkdir(parents=True,exist_ok=True)
iconset=CACHE/'AppIcon.iconset';iconset.mkdir(exist_ok=True)
for points in [16,32,128,256,512]:
    for scale in [1,2]:
        pixels=points*scale
        name=f'icon_{points}x{points}'+('@2x' if scale==2 else '')+'.png'
        subprocess.run(['/usr/bin/sips','-z',str(pixels),str(pixels),str(SRC/'assets/AppIcon.png'),'--out',str(iconset/name)],check=True,stdout=subprocess.DEVNULL)
subprocess.run(['/usr/bin/iconutil','-c','icns',str(iconset),'-o',str(RES/'AppIcon.icns')],check=True)
shutil.copy2(SRC/'assets/AppIcon.png',RES/'AppIcon.png')
plist={'CFBundleExecutable':'SnapshotLedger','CFBundleIdentifier':'local.snapshotledger.app','CFBundleName':'财务快照','CFBundleDisplayName':'财务快照','CFBundlePackageType':'APPL','CFBundleVersion':'2','CFBundleShortVersionString':'0.2.0','CFBundleIconFile':'AppIcon','LSMinimumSystemVersion':'14.0','NSHighResolutionCapable':True,'NSPrincipalClass':'NSApplication'}
(APP/'Contents/Info.plist').write_bytes(plistlib.dumps(plist))
subprocess.run(['/usr/bin/swiftc','-module-cache-path',str(CACHE/'module-cache'),'-swift-version','5','-target','arm64-apple-macos14.0','-O',str(SRC/'Models.swift'),str(SRC/'Views.swift'),str(SRC/'Charts.swift'),str(SRC/'main.swift'),'-o',str(BIN/'SnapshotLedger')],check=True)
subprocess.run(['/usr/bin/codesign','--force','--deep','--sign','-',str(APP)],check=True)
subprocess.run([str(BIN/'SnapshotLedger'),'--self-test'],check=True)
print('APP',APP)
