#hxpico8 tool

This tool let you initialize and build pico8 projects in haxe using [hxpico8](https://github.com/YellowAfterlife/hxpico8).

##What is exactly doing this tool?

###Initialize your project

```
haxelib run hxpico8-tools init
```

It will ask you some question in order to initialize your project and install the dependancies if needed.
You will then have a config.json file which will be used for compilation / deployment.

###Build your project

```
haxelib run hxpico8-tools build
```

It will compile your project, backup the old p8 file (in case you've updated it with some graphics, sounds, ...), integrate the new compiled code and copy it back to the p8 directory.

Once it's done, you can go to pico8 and type:

```
LOAD MY-PROJECT.P8
RUN MY-PROJECT.P8
```

And enjoy

##How to install

```
haxelib git hxpico8-tools https://github.com/po8rewq/hxpico8-tools.git
```

##How to use this tool

```
mkdir /path/to/your/project
cd /path/to/your/project
haxelib run hxpico8-tools
```
