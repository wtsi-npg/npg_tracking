  Event.observe(window,'load', modal_rfid_form);
  var fld = $('rf_id_input');
  fld.focus();

  fld.observe('change',function() { login_with_rfid(fld.value) });

function modal_rfid_form() {
    var inputs = document.getElementsByTagName( 'input' );
    for (var i = 0; i < inputs.length; i++) {
      inputs[i].disabled=true;
    }
    var textareas = document.getElementsByTagName( 'textarea' );
    for (var i = 0; i < textareas.length; i++) {
      textareas[i].disabled=true;
    }
    var fld = $('rf_id_input');
    fld.disabled=false;
    fld.focus();
}

  function login_with_rfid(id) {
    id = id.replace(/(\n|\r)+$/, '');
    var rfid_box = $( 'rfid_box' );
    var doc_forms = document.getElementsByTagName( 'form' );
    for (var i = 0; i < doc_forms.length; i++) {
      inputElement = document.createElement( 'input' );
      inputElement.setAttribute( 'type', 'hidden' );
      inputElement.setAttribute( 'name', 'rfid' );
      inputElement.setAttribute( 'value', id );
      inputElement.setAttribute( 'id', 'rfid_hidden_element_' + i );
      doc_forms[i].appendChild( inputElement );
    }

    var d = new Date();
    new Ajax.Updater('rfid_box', SCRIPT_NAME + '/user/;rfid_check_ajax?milliseconds=' + d.getTime(),
      {method:'get',
        parameters:{
          rfid_tag:id,

        },
        onComplete:function(){
          new Effect.Highlight('rfid_box');
          var rfid_div = $( 'rfid_div' );
          if ( rfid_div ) {
           for (var i = 0; i < doc_forms.length; i++) {
             inputElement = $( 'rfid_hidden_element_' + i );
             if ( inputElement ) {
               doc_forms[i].removeChild( inputElement );
             }
           } 
           var fld = $('rf_id_input');

           fld.focus();
           new Form.Element.Observer(
             'rf_id_input',
             2, // seconds before acting
             function(element, value) {
               if ( value == '' || value == 'Enter rfid' ) {
               } else {
                 login_with_rfid( value );
               }
             }
           );
           false;
          } else {
            var inputs = document.getElementsByTagName( 'input' );
            for (var i = 0; i < inputs.length; i++) {
              inputs[i].disabled=false;
            }
            var textareas = document.getElementsByTagName( 'textarea' );
            for (var i = 0; i < textareas.length; i++) {
              textareas[i].disabled=false;
            }

            var verify_fc_tag_form = $('verify_fc_tag_form');
            var loader_username = $('loader_username').readAttribute('username');
            var returned_username = $('returned_username').readAttribute('username');

            if ( verify_fc_tag_form ) {
              if ( loader_username === returned_username ) {
                var verify_submit = $('verify_fc_submit');
                verify_fc_tag_form.removeChild( verify_submit );
              }
            }
            var verify_r1_tag_form = $('verify_r1_tag_form');
            if ( verify_r1_tag_form ) {
              if ( loader_username === returned_username ) {
                var verify_r1_submit = $('verify_r1_submit');
                verify_r1_tag_form.removeChild( verify_r1_submit );
              }
            }
            var verify_r2_tag_form = $('verify_r2_tag_form');
            if ( verify_r2_tag_form ) {
              var r2_loader_username = $('load_r2_div').readAttribute('username');
              if ( r2_loader_username === returned_username ) {
                var verify_r2_submit = $('verify_r2_submit');
                verify_r2_tag_form.removeChild( verify_r2_submit );
              }
            }

          }
        }
      }
    );
    false;
  }