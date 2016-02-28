<?php

class SensorModel {

	const ENABLED = true;
	const DISABLED = false;
	const ALL = null;

	private
		$sData = null,
		$sList = null
	;

	public function __construct() { }

	public function initData() {

		// Imposto di default il sensore "Media" ed elenco i sensori
		$this->sensorStatus->setSensorId(null);
		$this->enumerate(self::ENABLED);
	}

	public function sensordata() { return $this->sensorStatus; }

	public function sensorlist() { return $this->sList; }

}