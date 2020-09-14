package lime.tools;

import haxe.rtti.Meta;
import hxp.*;
import lime.tools.AssetHelper;
import lime.tools.CommandHelper;

class PlatformTarget
{
	public var additionalArguments:Array<String>;
	public var buildType:String;
	public var command:String;
	public var noOutput:Bool;
	public var project:HXProject;
	public var targetDirectory:String;
	public var targetFlags:Map<String, String>;
	public var traceEnabled = true;

	public function new(command:String = null, project:HXProject = null, targetFlags:Map<String, String> = null)
	{
		this.command = command;
		this.project = project;
		this.targetFlags = targetFlags;

		buildType = "release";

		if (project != null)
		{
			if (project.debug)
			{
				buildType = "debug";
			}
			else if (project.targetFlags.exists("final"))
			{
				buildType = "final";
			}
		}

		for (haxeflag in project.haxeflags)
		{
			if (haxeflag == "--no-output")
			{
				noOutput = true;
			}
		}
	}

	/**
		This is where the actual operations associated with the user's command are performed.

		Order of execution for each possible command:
		- `"display"` -> (-watch), display
		- `"clean"` -> (-watch), clean
		- `"update"` -> (-watch), (-clean), update
		- `"build"` -> (-watch), (-clean), (-rebuild), update, build
		- `"deploy"` -> (-watch), deploy
		- `"test"` -> (-watch), (-clean), (-rebuild), update, build, install, run, (+trace)
		- `"install"` -> (-watch), install
		- `"run"` -> (-watch), install, run, (+trace)
		- `"rerun"` -> (-watch), run, (+trace)
		- `"trace"` -> (-watch), trace
		- `"uninstall"` -> (-watch), uninstall

		Special case: Rebuilding a native library.
		- `"rebuild"` -> rebuild

		Notes:
		- `(-watch)` indicates that `watch` should be executed if the `-watch` targetFlag was passed. Other operations are similarly annotated.
		- `(+trace)` indicates that `trace` should be executed unless disabled with the `-notrace` targetFlag.
		- If the associated function is annotated with `@ignore`, skip it.
		- `rebuild` operates quite differently depending on whether it was triggered by the `"rebuild"` command or by the `-rebuild` targetFlag.
		- The `"install"` command isn't actually available, so the `install` function only executes as part of a `"run"` command.
	**/
	public function execute(additionalArguments:Array<String>):Void
	{
		// Log.info ("", Log.accentColor + "Using target platform: " + Std.string (project.target).toUpperCase () + Log.resetColor);

		this.additionalArguments = additionalArguments;
		var metaFields = Meta.getFields(Type.getClass(this));

		if ( /*!Reflect.hasField (metaFields.watch, "ignore") && */ (project.targetFlags.exists("watch") && command != "rebuild"))
		{
			Log.info("", "\n" + Log.accentColor + "Running command: WATCH" + Log.resetColor);
			watch();
			return;
		}

		if ((!Reflect.hasField(metaFields, "display") || !Reflect.hasField(metaFields.display, "ignore")) && (command == "display"))
		{
			display();
		}

		// if (!Reflect.hasField (metaFields.clean, "ignore") && (command == "clean" || targetFlags.exists ("clean"))) {
		if ((!Reflect.hasField(metaFields, "clean") || !Reflect.hasField(metaFields.clean, "ignore"))
			&& (command == "clean"
				|| (project.targetFlags.exists("clean") && (command == "update" || command == "build" || command == "test"))))
		{
			Log.info("", Log.accentColor + "Running command: CLEAN" + Log.resetColor);
			clean();
		}

		if ((!Reflect.hasField(metaFields, "rebuild") || !Reflect.hasField(metaFields.rebuild, "ignore"))
			&& (command == "rebuild" || ((command == "build" || command == "test") && project.targetFlags.exists("rebuild"))))
		{
			Log.info("", "\n" + Log.accentColor + "Running command: REBUILD" + Log.resetColor);

			// hack for now, need to move away from project.rebuild.path, probably

			if (project.targetFlags.exists("rebuild"))
			{
				project.config.set("project.rebuild.path", null);
			}

			rebuild();
		}

		if ((!Reflect.hasField(metaFields, "update") || !Reflect.hasField(metaFields.update, "ignore"))
			&& (command == "update" || command == "build" || command == "test"))
		{
			Log.info("", "\n" + Log.accentColor + "Running command: UPDATE" + Log.resetColor);
			// #if lime
			// AssetHelper.processLibraries (project, targetDirectory);
			// #end
			update();
		}

		if ((!Reflect.hasField(metaFields, "build") || !Reflect.hasField(metaFields.build, "ignore"))
			&& (command == "build" || command == "test"))
		{
			CommandHelper.executeCommands(project.preBuildCallbacks);

			Log.info("", "\n" + Log.accentColor + "Running command: BUILD" + Log.resetColor);
			build();

			CommandHelper.executeCommands(project.postBuildCallbacks);
		}

		if ((!Reflect.hasField(metaFields, "deploy") || !Reflect.hasField(metaFields.deploy, "ignore")) && (command == "deploy"))
		{
			Log.info("", "\n" + Log.accentColor + "Running command: DEPLOY" + Log.resetColor);
			deploy();
		}

		if ((!Reflect.hasField(metaFields, "install") || !Reflect.hasField(metaFields.install, "ignore"))
			&& (command == "install" || command == "run" || command == "test"))
		{
			Log.info("", "\n" + Log.accentColor + "Running command: INSTALL" + Log.resetColor);
			install();
		}

		if ((!Reflect.hasField(metaFields, "run") || !Reflect.hasField(metaFields.run, "ignore"))
			&& (command == "run" || command == "rerun" || command == "test"))
		{
			Log.info("", "\n" + Log.accentColor + "Running command: RUN" + Log.resetColor);
			run();
		}

		if ((!Reflect.hasField(metaFields, "trace") || !Reflect.hasField(metaFields.trace, "ignore"))
			&& (command == "test" || command == "trace" || command == "run" || command == "rerun"))
		{
			if (traceEnabled || command == "trace")
			{
				Log.info("", "\n" + Log.accentColor + "Running command: TRACE" + Log.resetColor);
				this.trace();
			}
		}

		if ((!Reflect.hasField(metaFields, "uninstall") || !Reflect.hasField(metaFields.uninstall, "ignore")) && (command == "uninstall"))
		{
			Log.info("", "\n" + Log.accentColor + "Running command: UNINSTALL" + Log.resetColor);
			uninstall();
		}
	}

	/**
	    Compile the game's code and generate the resulting binaries and associated files.
	**/
	@ignore public function build():Void {}

	/**
		Delete all generated files in the target directory to ensure a clean build.
	**/
	@ignore public function clean():Void {}

	/**
		Compress and optionally upload the generated game.
	**/
	@ignore public function deploy():Void {}

	/**
		One of two things should be printed:
		If the "output-file" targetFlag is present, the location of the generated file.
		Otherwise, the content of the hxml file that would be passed to the haxe compiler to build the project.
	**/
	@ignore public function display():Void {}

	/**
	    Install the game to the target device.
	**/
	@ignore public function install():Void {}

	/**
		Rebuild native libraries for the given project, usually a haxelib such as lime.

		Note that this function may be called in response to a "rebuild" command,
		or it could be called as part of a "build" or "test" command if the
		-rebuild targetFlag was passed.

		If it's the rebuild **command**, this is operating on a HXProject that's actually
		a haxelib, such as lime. If it's the -rebuild **flag**, then this is operating on
		a user HXProject, such as a game. This is the only function with this distinction,
		and the only one that will be called on a HXProject representing a haxelib.

		https://community.openfl.org/t/updated-documentation-for-extensions/591/6

		For the **command**: rebuild all architectures, with limited capability to change
		what's built via command line parameters.

		For the **flag**: only rebuild the architecture needed for the current project.
	**/
	@ignore public function rebuild():Void {}

	/**
	    Run the game.
	**/
	@ignore public function run():Void {}

	/**
	    Begin a logging process to show the game's output in the console
	**/
	@ignore public function trace():Void {}

	/**
	    Uninstall the game from the device
	**/
	@ignore public function uninstall():Void {}

	/**
		Copies needed non-code assets to the Export folder
	**/
	@ignore public function update():Void {}

	/**
		Rerun the current command when any source directory changes.

		Currently has no practical effect for any built-in target.
	**/
	@ignore public function watch():Void {}
}
