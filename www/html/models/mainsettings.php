<?php

class MainSettingsModel {

	private
		$slist = null
	;

	public function __construct() {

		$this->slist = new SensorListModel();
	}

	public function _isset($d) {

		return true;
	}

	public function __get($d) {

		return '';
	}
}