<?php

class SensorReportController extends SensorStatsController {

	public function __construct($model, $init = true) {

		parent::__construct($model, $init);
		$this->model->setFunction('reportSensori');
		$this->setDate(false);
	}
}