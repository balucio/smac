<?php

class ProgramDataView {

	private $model;
	private $controller;

	public function __construct($controller, $model) {

		$this->controller = $controller;
		$this->model = $model;
	}

	public function render() {

		$rv = (object)[
			'detaglio' => $this->model->dettaglio,
			'temp_antigelo' => $this->model->antigelo,
			'temp_riferimento' => $this->encodeHtml($this->model),
			'temp_rif_att' => $this->model->rif_temp_attuale
		];

		return '<pre>' . json_encode( $rv, JSON_PRETTY_PRINT) . '</pre>';
//		return json_encode( $rv );
	}

	private function encodeHtml($pdata) {

		$tpl = Template::get()->loadTemplate('tempriferimento.tpl');
		return $tpl->render([ 'temperature' => $pdata->temperature ]);
	}
}