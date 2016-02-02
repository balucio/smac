<?php

class ProgramDataView {

	private $model;
	private $controller;

	public function __construct($controller, $model) {

		$this->controller = $controller;
		$this->model = $model;
	}

	public function render() {

		$rv = (object)[ 'jdata' => $this->model->programdata() ];
		$rv->html = $this->encodeHtml($rv->jdata);

		//return '<pre>' . json_encode( $this->model->programdata(), JSON_PRETTY_PRINT) . '</pre>';
		return json_encode( $rv );
	}

	private function encodeHtml($pdata) {

		$tpl = Template::get()->loadTemplate('temperature_riferimento');
		$dcr = new Decorator();

		return $tpl->render([
			'decorateTemperature' => [$dcr, 'decorateTemperature'],
			'decorateUmidity' => [$dcr, 'decorateUmidity'],
			'antigelo' => $pdata->antigelo,
			'temperature' => $pdata->temperature
		]);
	}
}