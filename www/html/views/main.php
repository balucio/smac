<?php

class MainView extends BaseView {

	private
		$template = null,
		$data = []
	;

	public function __construct($model, $template) {

		parent::__construct($model);
		$this->template = $template;
	}

	protected function addData($data) {

		if (!is_array($data))
			$data = [ $data ];

		foreach ($data as $k => $v) {
			$this->data[$k] = $v;
		}
	}

	public function render() {

		$this->addData([
			'css' => Assets::get()->Css(),
			'js' => Assets::get()->Js(),
			'internalCss' => Assets::get()->InternalCss()
		]);

		$tpl = Template::get()->loadTemplate($this->template);
		return $tpl->render($this->data);
	}
}