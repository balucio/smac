 <?php

class ImpostazioniView extends BaseView {

	public function render() {

		$tpl = Template::get()->loadTemplate('impostazioni.tpl');
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