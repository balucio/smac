<?php

class SensorDriverListController extends BaseController {

	private
		$did = null
	;

	public function __construct($model, $init = true) {

		parent::__construct($model, $init);
		$this->setDefaultAction('setDriverId');
	}

	public function setDriverId($did = null) {

		$did !== null && $this->did = (int)$did;

		$this->model->enumerate($this->did);
	}

	protected function initFromRequest() {

		$this->did = (int)Request::Attr('driver', null);

	}
}