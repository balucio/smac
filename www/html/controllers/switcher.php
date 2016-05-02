<?php

class SwitcherController extends BaseController {

	public function __construct($model) {

		parent::__construct($model, false);

		$this->setDefaultAction('state');
	}

    public function state() { $this->model->state(); }
    public function on() { $this->model->on(); }
    public function off() { $this->model->off(); }
    public function reload() { $this->model->reload(); }
}