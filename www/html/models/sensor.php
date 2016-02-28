<?php

class SensorModel {

	private
		$sensorData = null,
		$sensorList = null
	;

	public function __construct() {
		$this->sensorData = new SensorDataModel();
		$this->sensorList = new SensorListModel();
	}

	public function initData($sid = 0) {

		// Selezionato per default sensore media "Media" 0
		$this->sensorData->setSensorId(null);
		$this->sensorList->sensorList(SensorListModel::ALL, $selected = 0 );
	}

	public function getData() {
		return $this->sensorData;
	}

	public function getlist() {

		return $this->sensorList->getList($includeAverage = true);
	}

}