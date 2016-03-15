/** Jquery plugin to show modal */

(function ( $ ) {

	$.fn.showDeleteConfirm = function(header, body, callback) {

		// Visualizzo il pannello di conferma
		self = this;
		this.modal();
		
		this.on('hidden.bs.modal', function () {
				$(this).data('bs.modal', null);
		});

		// Popolo il modale e imposto la callback
		this.find('div.modal-header').html($(header).html())
			.find('div.modal-body').html($(body).html())
			.find('a.btn-ok').click( function(e) {

				e.preventDefault();
				typeof callback === 'function' && callback();
				self.modal('hide');
			});

		return this;
	};
}( jQuery ));
