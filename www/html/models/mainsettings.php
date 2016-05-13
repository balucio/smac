<?php

class MainSettingsModel {

	private

		$db = null
	;

	private static $s =[
		'manualSensor' => [ Db::CURR_MANUAL_SENSOR, 0 ],
		'antifreezeSensor' => [ Db::CURR_ANTIFREEZE_SENSOR, 0 ],
		'manualTemp' => [ Db::CURR_MANUAL_TEMP, 20 ],
		'antifreezeTemp' => [ Db::CURR_ANTIFREEZE_TEMP, 5 ],
		'pinRele' => [ Db::CURR_GPIO_PIN_RELE, 24 ]
	];

	public function __construct() {

		$this->db = Db::get();

	}

	public function exists($sid) {

		$sd = new SensorDataModel();
		return $sd->exists($sid);
	}

	public function __set($d, $v) {


		if (isset(self::$s[$d]))
			$this->db->saveSetting(self::$s[$d][0], $v);
	}

	public function __get($d) {
		if ($d == 'list')
			return $this->getList();

		if (isset(self::$s[$d]))
			return $this->db->readSetting(self::$s[$d][0], self::$s[$d][1]);

		return null;
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