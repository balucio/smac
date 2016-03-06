<?php

class SituazioneView extends BaseView {

	public function render() {

		$tpl = Template::get()->loadTemplate('situazione.tpl');

		$situazione = new StatoSensoriView(
			$this->model->sensor
		);

		$programmi = new StatoSistemaView(
			$this->model->program
		);

		return $tpl->render([
			'css' => Assets::get()->Css(),
			'js' => Assets::get()->Js(),
			'sit_selected' => 'active',
			'situazione' => $situazione->render(),
			'programmazione' => $programmi->render()
		]);
	}

}