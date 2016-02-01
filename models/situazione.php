<?php

class SituazioneModel {

    private
        $sensorStatus = null,
        $programStatus = null
    ;

    public function __construct() {

        $this->sensorStatus = new SensorStatusModel();
        $this->programStatus = new ProgramStatusModel();
    }

    public function initData() {

        // Imposto di default il sensore "Media" ed elenco i sensori
        $this->sensorStatus->initData();
        $this->programStatus->initData();
    }

    public function situazione() { return $this->sensorStatus; }

    public function programmazione() { return $this->programStatus; }
}