package lime.tools;


class LaunchStoryboard {


	public var assetsPath:String;
	public var assets:Array<LaunchStoryboardAsset>;
	public var path:String;


	public function new () {
		
		assets = [];
		
	}


	public function clone ():LaunchStoryboard {

		var launchStoryboard = new LaunchStoryboard ();
		launchStoryboard.assetsPath = assetsPath;
		launchStoryboard.assets = assets.copy ();
		launchStoryboard.path = path;
		
		return launchStoryboard;

	}
	
	
	public function merge (launchStoryboard:LaunchStoryboard):Void {

		if (launchStoryboard != null) {

			if (launchStoryboard.assetsPath != null) assetsPath = launchStoryboard.assetsPath;
			if (launchStoryboard.assets != null) assets = launchStoryboard.assets;
			if (launchStoryboard.path != null) path = launchStoryboard.path;
			
		}

	}


}


class LaunchStoryboardAsset {
	
	
	public var type:String;
	
	
	public function new (type:String) {
	
		this.type = type;
	
	}
	
	
}


class ImageSet extends LaunchStoryboardAsset {
	
	
	public var name:String;
	
	
	public function new (name:String) {
	
		super("imageset");
		this.name = name;
		
	}
	
	
}