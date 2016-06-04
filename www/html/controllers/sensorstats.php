<?php

class SensorStatsController extends SensorBaseStatsController {


	public function __construct($model, $init = true) {

		parent::__construct($model, $init);
		$this->model->setFunction('reportMisurazioni');
		$this->setDate(true);
	}

}