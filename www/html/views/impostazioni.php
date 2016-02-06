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
		$dcr = new Decorator();

		Assets::get()->addCss('/css/programedit.css');

		return $tpl->render([
			'css' => Assets::get()->Css(),
			'js' => Assets::get()->Js(),
			'imp_selected' => 'active',
			'programedit' => $this->model->pdata,
			'programlist' => $this->model->plist,
			'decorateShortDay' => [ $dcr, 'decorateShortDay' ],
			'decorateDay' => [ $dcr, 'decorateDay' ],
			'decorateShedule' => [ $dcr, 'decorateShedule' ]
		]);
	}

}