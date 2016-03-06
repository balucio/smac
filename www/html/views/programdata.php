<?php

class ProgramDataView extends BaseView {

	public function render() {

		$dcr = new Decorator();

		$rv = (object)[
			'dettaglio' => $this->model->dettaglio,
			'temp_antigelo' => $this->model->antigelo,
			'temperature' => $this->model->temperature,
			'temp_riferimento' => $this->encodeHtml($this->model),
			'temp_rif_att' => $dcr->decorateTemperature($this->model->rif_temp_attuale)
		];

//		return '<pre>' . json_encode( $rv, JSON_PRETTY_PRINT) . '</pre>';
		return json_encode( $rv );
	}

	private function encodeHtml($pdata) {

		$tpl = Template::get()->loadTemplate('tempriferimento.tpl');
		return $tpl->render([ 'temperature' => $pdata->temperature ]);
	}
}