<?php

class MainSettingsModel {

	private

		$db = null
	;

	public function __construct() {

		$this->db = Db::get();

	}

	public function exists($sid) {

		$sd = new SensorDataModel();
		return $sd->exists($sid);
	}

	public function __set($d, $v) {

		$setting_name = null;

		switch ($d) {

			case 'manualSensor' : $setting_name = Db::CURR_MANUAL_SENSOR;
				break;

			case 'antifreezeSensor' : $setting_name = Db::CURR_ANTIFREEZE_SENSOR;
				break;

			case 'manualTemp' : $setting_name = Db::CURR_MANUAL_TEMP;
				break;

			case 'antifreezeTemp' : $setting_name = Db::CURR_ANTIFREEZE_TEMP;

			case 'pinRele' : $setting_name = Db::CURR_GPIO_PIN_RELE;
		}

		if ($setting_name != null)
			$this->db->saveSetting($setting_name, $v);
	}

	public function __get($d) {

		switch ($d) {
			case 'list' :
				return $this->getList();

			case 'manualSensor' :
				return $this->db->readSetting(Db::CURR_MANUAL_SENSOR, 0);

			case 'antifreezeSensor' :
				return $this->db->readSetting(Db::CURR_ANTIFREEZE_SENSOR, 0);

			case 'manualTemp' :
				return $this->db->readSetting(Db::CURR_MANUAL_TEMP, 20);

			case 'antifreezeTemp' :
				return $this->db->readSetting(Db::CURR_ANTIFREEZE_TEMP, 5);

			case 'pinRele' :
				return $this->db->readSetting(Db::CURR_GPIO_PIN_RELE, 24);

			default:
				return null;
		}
	}

	private function getList() {

		$slist = new SensorListModel();
		$slist->enumerate(SensorListModel::ENABLED, -1);
		return $slist->get(true);
	}


	public function _isset($d) {
		return in_array($d, [
			'list', 'manualSensor', 'antifreezeSensor', 'manualTemp', 'antifreezeTemp', 'pinRele']
		);
	}

}