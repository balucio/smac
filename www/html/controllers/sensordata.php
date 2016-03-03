<?php

class SensorDataController extends GenericController {

	private
		$sid = null
	;

	public function __construct($model) {

		$this->model = $model;
		$this->sid = (int)Request::Attr('sensor', null);
	}

	public function setSensorId($sid = null) {

		$sid !== null && $this->sid = (int)$sid;

		$this->model->setSensorId($this->sid);
	}
}