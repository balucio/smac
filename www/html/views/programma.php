<?php

class ProgrammaView {

	private $model;
	private $controller;

	private $tplh;

	public function __construct($controller, $model) {

		$this->controller = $controller;
		$this->model = $model;

		$this->tplh = Template::get();
	}

	public function render() {

		return $this->{$this->controller->action}();
	}

	private function elenco() {

		Assets::get()->addInternalCss('
			@media (min-width: @screen-lg)
			{
			    #elenco-programmi { display: block; }
			}
		');

		$tpl = $this->tplh->loadTemplate('programlist');

		return $tpl->render([
			'programmi' => $this->model->plist
		]);
	}

	private function dati() {

		Assets::get()->addJs('/js/boostrap-tabcollapse.js');

		$dcr = new Decorator();
		$tpl = $this->tplh->loadTemplate('programedit.tpl');

		return $tpl->render([
			'tabcollapse' => '$("#programmazione-settimanale").tabCollapse();',
			'giorni' => $this->model->programma->dettaglio,
			'decorateDay' => [ $dcr, 'decorateDay' ],
			'decorateShordDay' => [ $dcr, 'decorateShordDay' ]
		]);
	}

	private function salvaattuale() {
		return json_encode(['result' => $this->controller->status]);
	}
}