<?php

class SensorDataController extends BaseController {

	private
		$sid = null
	;

	public function __construct($model, $init = true) {

		parent::__construct($model, $init);
		$this->setDefaultAction('setSensorId');
	}

	public function setSensorId($sid = null) {

		$sid !== null && $this->sid = (int)$sid;

		$this->model->setSid($this->sid);
	}

	protected function initFromRequest() {

		$this->sid = (int)Request::Attr('sensor', null);

	}
}