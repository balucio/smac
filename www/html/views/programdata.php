<?php

class ProgramDataView extends BaseView {

	public function render() {

		$dcr = new Decorator();

		return json_encode((object)[
			'dettaglio' => $this->model->dettaglio,
			'temp_antigelo' => $this->model->antigelo,
			'temperature' => $this->model->temperature,
			'temp_riferimento' => $this->encodeHtml($this->model),
			'temp_rif_att' => $dcr->decorateTemperature($this->model->rif_temp_attuale)
		] );
	}

	private function encodeHtml($pdata) {

		$tpl = Template::get()->loadTemplate('tempriferimento.tpl');
		return $tpl->render([ 'temperature' => $pdata->temperature ]);
	}
}