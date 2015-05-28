package data
{
	import net.reconditeden.JsonFile;
	import net.reconditeden.debug.assert;

	/**
	 * @author ReconditeArcher (Sakhatskiy Ilya)
	 */
	public class ConverterSettings extends JsonFile
	{
		public function ConverterSettings(jsonFile:String)
		{
			super(jsonFile);
		}

		public function get validClientDataProperties():Array
		{
			assert(_jsonObject['validClientDataProperties'] != null, 'Bad settings data');
			return _jsonObject['validClientDataProperties'] as Array;
		}

		public function get backLinkName():String
		{
			assert(_jsonObject['backLinkName'] != null, 'Bad settings data');
			return _jsonObject['backLinkName'] as String;
		}

		public function get scenarioPointUids():Array
		{
			assert(_jsonObject['scenarioPointUids'] != null, 'Bad settings data');
			return _jsonObject['scenarioPointUids'] as Array;
		}

		public function get scenarioWayPointsUids():Array
		{
			assert(_jsonObject['scenarioWayPointsUids'] != null, 'Bad settings data');
			return _jsonObject['scenarioWayPointsUids'] as Array;
		}

		public function get clientDataOpeningSymbol():String
		{
			assert(_jsonObject['clientDataOpeningSymbol'] != null, 'Bad settings data');
			return _jsonObject['clientDataOpeningSymbol'] as String;
		}

		public function get clientDataClosingSymbol():String
		{
			assert(_jsonObject['clientDataClosingSymbol'] != null, 'Bad settings data');
			return _jsonObject['clientDataClosingSymbol'] as String;
		}
	}
}
