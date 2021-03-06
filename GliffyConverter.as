package
{
	import data.ConverterSettings;

	import flash.display.Sprite;
	import flash.events.Event;

	import net.reconditeden.JsonFile;
	import net.reconditeden.SmartStage;
	import net.reconditeden.UI.Button;
	import net.reconditeden.utils.FileWorks;

	import tools.FilesMerger;
	import tools.GliffyParser;

	/**
	 * @author Ilya Sakhatskiy
	 */
	[SWF(width='400', height='100', backgroundColor='#999999')]
	public class GliffyConverter extends Sprite
	{
		private var _conversionResult:String;
		private var _convertBtn:Button;
		private var _saveButton:Button;
		private var _mergeButton:Button;
		//
		private var _initiated:Boolean;
		private var _parser:GliffyParser;
		// ----------------------------------------------------------------------------
		// Public methods
		// ----------------------------------------------------------------------------
		public function GliffyConverter()
		{
			if (stage) {
				init();
			} else {
				addEventListener(Event.ADDED_TO_STAGE, init);
			}
		}
		
		private function init(event:Event = null):void
		{
			removeEventListener(Event.ADDED_TO_STAGE, init);
			loadNecessary();
		}

		private function loadNecessary():void
		{
			var settings:ConverterSettings = new ConverterSettings('SampleSettings.json');
			settings.addEventListener(JsonFile.READY, onNecessaryLoaded);
		}

		private function onNecessaryLoaded(e:Event):void
		{
			var settings:ConverterSettings = ConverterSettings(e.target);
			_parser = new GliffyParser(settings);

			var smartStage:SmartStage = new SmartStage();
			smartStage.init(stage);
			SmartStage.stage.addEventListener(Event.RESIZE, onResize);

			_convertBtn = new Button('Сконвертировать', 0x80FF00, 0x000000, onConvertButton);
			addChild(_convertBtn);

			_saveButton = new Button('Сохранить', 0xFF4621, 0x000000, onSaveButton);
			_saveButton.visible = false;
			addChild(_saveButton);

			_mergeButton = new Button('Склеить', 0xFFFB00, 0x000000, onMergeButton);
			addChild(_mergeButton);

			_initiated = true;

			onResize();
		}

		private function onMergeButton():void
		{
			var merger:FilesMerger = new FilesMerger();
			merger.mergeFiles();
		}
		
		private function onConvertButton():void
		{
			var fileWorks:FileWorks = new FileWorks();
			fileWorks.addEventListener(FileWorks.ALL_FILES_LOADED,
					// On complete
					function (event:Event):void
					{
						var fileWorks:FileWorks = FileWorks(event.target);
						var gliffyJson:String = fileWorks.data.readUTFBytes(fileWorks.data.length);

						_conversionResult = _parser.convert(gliffyJson);

						_saveButton.visible = true;
						onResize();
					}
			);
			
			fileWorks.load();
		}
		
		private function onSaveButton():void
		{
			var saveFileWorks:FileWorks = new FileWorks();
			saveFileWorks.save(_conversionResult);
		}
		
		private function onResize(event:Event = null):void
		{
			if (_initiated) {
				_convertBtn.x = SmartStage.stage.stageWidth / 4;
				_convertBtn.y = SmartStage.stage.stageHeight / 2 - _convertBtn.height / 2;
				
				_saveButton.x = SmartStage.stage.stageWidth / 4;
				_saveButton.y = SmartStage.stage.stageHeight / 2 + _saveButton.height / 2;

				_mergeButton.x = SmartStage.stage.stageWidth / 4 * 3;
				_mergeButton.y = SmartStage.stage.stageHeight / 2 - _mergeButton.height / 2;
			}
		}
		
	}
}
