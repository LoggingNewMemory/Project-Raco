## How to Port Modules to Project Raco

First of all, read [THIS](https://github.com/LoggingNewMemory/Project-Raco/blob/main/PLUGIN.md) first
Done? Good 

Now here's the thing. Raco Doesn't have WebUI Support (as for now 4.0) but in the future might have.

So, as you know there's no post-fs-data.sh here, there's only service.sh (Yea I make the name same cuz why not? Won't burden the porters)

Ye anyway easy

module.prop > rename it to raco.prop then add RacoPlugin=1

Banner.png? > Nah, make it Logo.png with 1:1 Aspect ratio (advise, do not make it more than 512x512, why? if you make it 4k then you just gonna make it heavier -_- (Come on))

install.sh > this is crucial, you must make it like you write service.sh (shell language only, not using magisk module syntax)

uninstall.sh > executed during uninstallation, so you better not leave it empty if you change something -_-

Ye I guess that's it Good luck Dev
Want to submit your plugin? Send on the [Dormitory](https://t.me/YamadaDorm) and tag me @KanagawaYamadaVTeacher 
