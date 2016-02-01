<?php

class SensorDataController extends GenericController {

	public function __construct($model) {
		$this->model = $model;
        $this->checkParam();
	}

	public function setSensorId($sensorId) {

		$this->model->setSensorId($sensorId);
	}

    private function checkParam() {

        $sensor = (int)Request::Attr('sensor', null);
        ($sensor <= 0 || $sensor >= 254 ) && $sensor = null;

        $this->setSensorId($sensor);
    }
}