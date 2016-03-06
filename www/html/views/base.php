<?php

class BaseView {

	protected $model;

	public function __construct($model) {

		$this->model = $model;
	}

	public function render() { return ''; }

}