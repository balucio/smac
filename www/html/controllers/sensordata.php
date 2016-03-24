<?php

class SensorDataController extends BaseController {

	private
		$sid = null
	;

	public function __construct($model, $init = true) {

		parent::__construct($model, $init);
		$this->setDefaultAction('getData');
	}

	public function getMeasure() {

		$this->model->collectEnviromentalData($this->sid);
	}

	public function getData() {

		$this->model->collectData($this->sid);
	}

	protected function initFromRequest() {

		$sid = Request::Attr('sensor', null);

		$this->sid = (int)($this->model->exists($sid) ? $sid : 0);
	}
}