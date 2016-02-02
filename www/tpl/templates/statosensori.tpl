<div class="col-xs-12 col-md-6">
  <div class="panel panel-primary">
    <div class="panel-heading">Stato sensori</div>
    <div class="panel-body">
      <select id="sensore" class="selectpicker" data-width="100%">
        <option value="0">Media Sensori</option>
        <option data-divider="true"></option>
        {{#in_average_sensor}}
        <option value="{{id_sensore}}">{{nome_sensore}}</option>
        {{/in_average_sensor}}
        {{#have_others}}<option data-divider="true"></option>{{/have_others}}
        {{#other_sensor}}
        <option value="{{id_sensore}}">{{nome_sensore}}</option>
        {{/other_sensor}}
      </select>
      <h3 class="temperature">
        <div class="col-xs-6 col-md-3 text-right"><small>Temperatura :</small></div>
        <div class="col-xs-6 col-md-3">
          <span class="wi wi-thermometer" aria-hidden="true"></span>
          <span id="temperature-value">{{#decorateTemperature}} {{sensor.temperatura}} {{/decorateTemperature}}</span>
          <span class="wi wi-celsius fa-1x" aria-hidden="true"></span>
        </div>
      </h3>
      <br class="clearfix visible-xs-block">
      <h3 class="humidity">
        <div class="col-xs-6 col-md-3 text-right"><small>Umidità :</small></div>
        <div class="col-xs-6 col-md-3">
          <span class="wi wi-humidity" aria-hidden="true"></span>
          <span id="humidity-value">{{#decorateUmidity}}{{sensor.umidita}}{{/decorateUmidity}}</span>
          <span class="fa fa-percent" aria-hidden="true"></span>
        </div>
      </h3>
      <div class="clearfix"></div>
      <hr class="col-xs-10 col-md-10" style="" />

      <div class="col-xs-12 col-md-12" id="andamento-temperatura" style="height:225px;"></div>
      <div class="col-xs-12 col-md-12" id="andamento-umidita" style="height:225px;"></div>

    </div>
    <div class="panel-footer text-center">
      <small class="text-muted">
        Ultimo aggiornamento <span id="last-update">{{#decorateDateTime}}{{sensor.ultimo_aggiornamento}}{{/decorateDateTime}}</span>
      </small>
    </div>
  </div>
</div>