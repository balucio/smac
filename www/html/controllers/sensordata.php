<?php

class SensorDataController extends GenericController {

	private
		$sid = null
	;

	public function setSensorId($sid = null) {

		$sid !== null && $this->sid = (int)$sid;

		$this->model->setSensorId($this->sid);
	}

	protected function initFromRequest() {

		$this->sid = (int)Request::Attr('sensor', null);

	}
}