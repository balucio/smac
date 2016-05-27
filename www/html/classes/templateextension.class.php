<?php

class TemplateExtension extends Twig_Extension {

	public function getName() { return 'SmacDecorator'; }

	public function getFilters() {

		$dec = new Decorator();

		return array(
			new Twig_SimpleFilter('Temperature', array($dec, 'decorateTemperature')),
			new Twig_SimpleFilter('DateTime', array($dec, 'decorateDateTime')),
			new Twig_SimpleFilter('ShortDay', array($dec, 'decorateShortDay')),
			new Twig_SimpleFilter('Interval', array($dec, 'decorateInterval')),
			new Twig_SimpleFilter('Umidity', array($dec, 'decorateUmidity')),
			new Twig_SimpleFilter('Time', array($dec, 'decorateTime')),
			new Twig_SimpleFilter('Day', array($dec, 'decorateDay')),
		);
	}
	
}

?>