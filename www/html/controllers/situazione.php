<?php

class SituazioneController extends BaseController {

	public function __construct($model) {

		parent::__construct($model, false);

		$this->setDefaultAction('view');
	}

	public function view() {

		$this->model->init();
	}
}