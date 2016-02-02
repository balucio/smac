<?php

class ImpostazioniView {

	private
		$model,
		$controller
	;

	public function __construct($controller, $model) {

		$this->controller = $controller;
		$this->model = $model;
	}

	public function render() {

		$tpl = Template::get()->loadTemplate('impostazioni');

		$plist = new ProgrammaView($this->controller->programma, $this->model->programma);
		$pedit = new ProgrammaView($this->controller->dettaglio, $this->model->programma);

		return $tpl->render([
			'css' => Assets::get()->Css(),
			'js' => Assets::get()->Js(),
			'imp_selected' => 'active',
			'programedit' => $pedit->render(),
			'programlist' => $plist->render()

		]);
	}

}