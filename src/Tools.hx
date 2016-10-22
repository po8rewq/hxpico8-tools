import sys.io.Process;
import sys.io.File;
import sys.FileSystem;
import haxe.io.Path;
import haxe.Template;
import haxe.Resource;

class Tools
{
  static inline var CONFIG_FILE = "build.json";
  static inline var DEFAULT_VERSION = 8;
  static inline var HXPICO8_LIB_GIT = "git@github.com:po8rewq/hxpico8.git";

  static inline function main()
  {
    var haxelibDir = Sys.getCwd();
    var userDir = Sys.args().pop();
    Sys.setCwd( userDir );

    var args = Sys.args();
    var cmd = args.length == 0 ? "help" : args[0];
    var params : Dynamic = args.length == 0 ? {} : getParams();

    switch (cmd) {
      case "build": build();
      case "init": init(params);
      default: help();
    }
  }

  static function getParams(): Dynamic
  {
    var obj = Sys.args();
    obj.shift();

    var params = {};
    for(o in obj)
    {
      if(o.charAt(0)=="-")
      {
        var r = ~/[=]+/g;
        var rr = r.split(o);
        if(rr.length!=2) continue;
        Reflect.setField(params, StringTools.replace(rr[0], "-", ""), rr[1]);
      }
    }

    return params;
  }

  static function init(params: InitConfig)
  {
    var cwd = Sys.getCwd();
    if( FileSystem.exists(Path.join([cwd, CONFIG_FILE])) )
    {
      var confirmation = askForParam("The project has already a config file. Are you sure you want to reset this project? Y/n", "n");
      if(confirmation == "n")
      {
        Sys.exit(0);
      }
      else if(confirmation != "Y")
      {
        Sys.println('$confirmation is not a valid choice');
        Sys.exit(1);
      }
    }

    // check if the lib is already installed
    var lib = new Process("haxelib", ["list", "hxpico8"]);
    if(lib.stdout.readAll().toString() == "")
    {
      var r = Sys.command("haxelib", ["git", "hxpico8", HXPICO8_LIB_GIT]);
      if(r != 0)
        Sys.exit(r);
    }
    lib.close();

    Sys.println('Init project in $cwd');

    // ask for additional information
    var configData: Dynamic = {};

    var tmp = askForParam("Project name");
    Reflect.setField(configData, "projectName", tmp);

    var tmp = askForParam("The haxe output directory", Path.join([cwd, "bin"]), validatePath);
    Reflect.setField(configData, "out", tmp);

    var tmp = askForParam("The haxe source directory", Path.join([cwd, "src"]), validatePath);
    Reflect.setField(configData, "src", tmp);

    Reflect.setField(configData, "main", "Main.hx");

    var tmp = askForParam("The pico8 output directory", null, validatePath);
    Reflect.setField(configData, "export", tmp);

    // create a config file in the current directory
    var config = new Template( Resource.getString("config") ).execute(configData);
    File.saveContent(Path.join([cwd, CONFIG_FILE]), config);

    // Check if all dirs exists
    if(!FileSystem.exists(Reflect.field(configData, "src")))
      FileSystem.createDirectory(Reflect.field(configData, "src"));

    if(!FileSystem.exists(Reflect.field(configData, "out")))
      FileSystem.createDirectory(Reflect.field(configData, "out"));

    if(!FileSystem.exists(Reflect.field(configData, "export")))
      FileSystem.createDirectory(Reflect.field(configData, "export"));

    // create the default p8 file
    var p8file = new Template( Resource.getString("p8") ).execute({
      version: params.version == null ? DEFAULT_VERSION : params.version
    });
    File.saveContent(Path.join([
      Reflect.field(configData, "out"),
      Reflect.field(configData, "projectName") + ".p8"
    ]), p8file);

    // Create the haxe entry point
    var mainFile = new Template( Resource.getString("main") ).execute(configData);
    File.saveContent(Path.join([
      Reflect.field(configData, "src"),
      Reflect.field(configData, "main")
    ]), mainFile);
  }

  static function askForParam( txt: String, ?defaultValue: String, ?validate: String->Bool ) : String
  {
    Sys.print(txt + (defaultValue == null ? "" : ' (default: $defaultValue)') + ": ");
    var result = Sys.stdin().readLine();

    if(result == null || result == "")
    {
      if(defaultValue == null)
      {
        Sys.println("Please enter a value");
        Sys.exit(1);
      }
      result = defaultValue;
    }
    else
    {
      if( validate != null && !validate(result) )
      {
        Sys.println('$result is not valid');
        Sys.exit(1);
      }
    }
    return result;
  }

  static function validatePath(v: String):Bool
  {
    return FileSystem.exists(v);
  }

  static function help()
  {
    Sys.println("");
    Sys.println("This tool helps you build your haxe pico8 project:");
    Sys.println(" * help: display this help");
    Sys.println(" * init: init your project");
    Sys.println(" * build: build your project");
    Sys.println("");
    Sys.exit(0);
  }

  static function build()
  {
    Sys.println("");

    var cwd = Sys.getCwd();
    if( !FileSystem.exists( Path.join([cwd, CONFIG_FILE]) ) )
    {
      Sys.println("ERROR: please run init firt");
      Sys.exit(1);
    }

    var configData = haxe.Json.parse( File.getContent(Path.join([cwd, CONFIG_FILE])) );

    // backup the old p8 file
    var oldFilePath = Path.join([
      configData.build.export,
      configData.project
    ]) + ".p8";

    if( FileSystem.exists(oldFilePath) )
    {
      var backupFile = Path.join([
        configData.build.outputDir,
        configData.project
      ]) + ".p8.bak";
      File.copy(oldFilePath, backupFile);

      var newP8File = File.write(Path.join([
        configData.build.outputDir,
        configData.project
      ]) + ".p8", false);

      var fin = sys.io.File.read(backupFile, true);
      try {
        var t : P8Part = CONFIG;
        while(true)
        {
          var line = fin.readLine();
          if(line == "__lua__")
          {
            newP8File.writeString(line);
            t = CODE;
          }
          else if(line == "__gfx__") t = GFX;
          else if(line == "__gff__") t = GFF;
          else if(line == "__map__") t = MAP;
          else if(line == "__sfx__") t = SFX;
          else if(line == "__music__") t = MUSIC;

          if(t != CODE)
            newP8File.writeString(line + "\n");
        }
      } catch (e:haxe.io.Eof) {
        fin.close();
      }
      newP8File.close();

      FileSystem.deleteFile(backupFile);
    }

    var buildCommandLine : Array<String> = [
      "-cp", configData.build.sourceDir,
      "-main", configData.build.main,
      "-js", Path.join([configData.build.outputDir, configData.project]) + ".p8hx",
      "-lib", "hxpico8",
      "--macro", "p8gen.PgMain.use()",
      "-dce", "full"
    ];
    Sys.println("haxe " + buildCommandLine.join(" "));
    Sys.println("");

    var p = new Process("haxe", buildCommandLine);
    if( p.exitCode() != 0 )
    {
      Sys.println(p.stderr.readAll().toString());
      Sys.println("BUILD FAILED");
      Sys.exit(1);
    }

    Sys.println("BUILD COMPLETED");
    Sys.println("");

    File.copy(Path.join([configData.build.outputDir, configData.project]) + ".p8", oldFilePath);

    Sys.exit(0);
  }
}

enum P8Part {
  CONFIG;
  CODE;
  GFX;
  GFF;
  MAP;
  SFX;
  MUSIC;
}

typedef InitConfig = {
  var outputDir : String;
  @optional var sourceDir : String;
  @optional var main : String;
  @optional var version : Int;
}
