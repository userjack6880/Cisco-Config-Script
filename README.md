This is a very crude way to configure a switch via serial. Run either the Fedora or Ubuntu installer. Technically this could work under MacOS as well. No guarantees on anything working, and hasn't been updated since 2020.

There's no real documentation for this, it was written for internal use. Some references within the UI are specific for our environment. Figured it'd be useful to someone to modify and use as a framework. There will be some default assumptions that will not necessarially be something you want to use. The script uses the default switch password of "password".

Helptext

```
(sudo) perl configSwitch.pl [args]
   [0-9]         enables desired level of debugging
   -d --debug    enables debugging
   -r --reset    resets switch\n".
   -m --manual   manual IP assignment".
   -h --help     displays this help text
```

I've commented out accounting code since you're not likely to be doing internal accounting. Study and emulate if you wish. Same with the automatic IP assignment.

Licensed under MIT license.
