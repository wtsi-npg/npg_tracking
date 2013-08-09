function things_to_do_on_load(id_run, batch_id, rAndDCodes) {

  var p=['prephasing','phasing','signal_mean','noise'];
  for (var i=0;i<p.length;i++){
   var s=$(p[i]+'_graph');
   if(!s){continue;}
   s.src=SCRIPT_NAME + '/run/'+p[i]+'/' + id_run + '.png';
  }

  var lims_str = '' + batch_id;
  if(batch_id && ! (lims_str.match(/^\d{13}$/))) {
   new Ajax.Request(SCRIPT_NAME + '/../reflector', {
    requestHeaders: {Accept: 'application/xml, text/xml'},
    parameters: { url: lims_batches_url + batch_id + '.xml' },
    onSuccess: function(transport){
      var response = transport.responseXML;
      if(!response){
         _ss_ajax_warning('Problems connecting to Sequencescape!');
         return;
      }
      var batch_list = response.getElementsByTagName('batch');
      if(response && batch_list.length > 0){
        $('ss_ajax_status').update('Retrieved batch data from Sequencescape.');
        var laneDataHashByPosition = _batch_XML_DOM_to_hash(response);
        if( $('submit_manual_qc_finish') && 
            $H(laneDataHashByPosition).values().findAll(function(n){return n.get('type') != 'control'}).all(function(n){var s = n.get('qc_state'); return s == 'pass' || s == 'fail';}) ){
          $('submit_manual_qc_finish').show();
        };
        //$('ss_ajax_status').update("Got <pre>"+Object.toJSON(laneDataHashByPosition)+"</pre>");
	_add_columns_to_table('run_lanes', laneDataHashByPosition);
        $('ss_ajax_status').update('');
	// now get name info missing from batch.xml
	var url2name = new Hash();

	$$('a.sequencescape_id').pluck('href').map(function(l){url2name.set(l)});
	url2name.each(function(pair){
	  new Ajax.Request(SCRIPT_NAME + '/../reflector', {
            requestHeaders: {Accept: 'application/xml, text/xml'},
	    parameters: { url: pair.key+'.xml' },
            onSuccess: function(transport){
	      var response = transport.responseXML;
	      if(response){
	        var name = _search_xml_element_by_name(response, 'name');
		if (name){
		  $$('a.sequencescape_id').findAll(function(e){return e.href == pair.key}).each(function(e){
		    if (name.length > 30) {
		      name = name.replace(/_/g, " ");
		    }
		    e.update(name);
                    /* FIXME code bolow does not work on IE */
		    var ena = _search_xml_propertydescriptor_value_for_name(response, /ENA \w+ Accession Number/);
		    if(ena){ new Insertion.After(e,' <span class="smaller_font_85">('+ena+')</span>'); }
		    var cost_code = _search_xml_propertydescriptor_value_for_name(response, /Project cost code/);
		    if (cost_code && rAndDCodes.indexOf(cost_code) !== -1) {
                      var pos = 'project_' + e.getAttribute('position');
                      $(pos).update('<div class="r_and_d_watermark_container">' + $(pos).innerHTML + '<span class="r_and_d_watermark">R&amp;D</span></div>');
		    }
		    e.removeClassName('sequencescape_id');
		  });
		}
	      }
	    }
          });
	});
      }else{
        _ss_ajax_warning('No batch data from Sequencescape!');
      }
    },
    onCreate: function(){ $('ss_ajax_status').update('<img style="height:16px;width:16px;" src="/prodsoft/npg/gfx/spinner.gif" alt="spinner" />Getting Sequencescape batch data...') },
    onFailure: function(){ _ss_ajax_warning('Something went wrong getting batch data from Sequencescape....') } 
   });
  }

  beginrefresh();
}
function _add_columns_to_table (run_lanes_table, laneDataHashByPosition) {
  $(run_lanes_table).getElementsBySelector('tr').each( function(rowel){
    var rowchildren = rowel.childElements();
    var firstcell = rowchildren[0];
    if(firstcell.match('th')){
        $('ss_ajax_status').update("trying to insert th");
      new Insertion.After(firstcell,'<th>Library</th><th>Request</th><th>Sample</th><th>Study</th><th>Project</th>');
        $('ss_ajax_status').update("done insert th");
    }else if (firstcell.match('td')){
        $('ss_ajax_status').update("trying to insert td");
      var pos = rowchildren[0].innerHTML;
      var laneData = laneDataHashByPosition.get(pos);
      var cls = '';
      var qc_state = laneData.get('qc_state');
      if (qc_state) {
        cls = ' class="' + qc_state + '"';
      }
      if (laneData.get('hyb_buffer') == undefined) {
        $(firstcell).update($(firstcell).innerHTML + ' <span class="smaller_font_85 npg_nbsp">not spiked</span>');
      }
      new Insertion.After(firstcell,
          '<td>'+ _html_link(pos, 'assets', laneData.get('id'), laneData.get('name')) +'</td>'+
          '<td' + cls + '>'+ _html_link(pos, 'requests', laneData.get('request_id'), laneData.get('type')) +'</td>'+
          '<td>'+ _html_link(pos, 'samples', laneData.get('sample_id')) +'</td>'+
          '<td>'+ _html_link(pos, 'studies', laneData.get('study_id')) +'</td>'+
          '<td id="project_' + pos + '">'+ _html_link(pos, 'projects', laneData.get('project_id')) +'</td>'
      );
        $('ss_ajax_status').update("done insert td");
    }
  });
}

function _ss_ajax_warning(comment){
   $('ss_ajax_warning').appendChild(new Element('li').update(comment));
   Element.show('ss_ajax_warning');
   $('ss_ajax_status').update('');
   return;
}

function run_form(type) {
 var el      = "new_" + type;
 var spinner = type + "_spinner";
 var update  = type + "_update";
 var cancel  = type + "_cancel";
 Element.show(spinner);
 Element.hide(update);
 new Ajax.Updater(el,SCRIPT_NAME + '/' + type+'/;add_ajax',
 {method:'get',
  parameters:{id_run:id_run},
  onComplete:function(){
   Element.show(el);
   Element.hide(spinner);
   Element.show(cancel);
   new Effect.Highlight(el);
 }});
}

function toggle_information(open) {
  $$('.tab').each (function(el) { el.removeClassName("current"); el.addClassName("noncurrent"); });
  $$('.info_box').each (function(el) { Element.hide(el); });
  if (open == 'status_history_tab') {
    Element.show('status');
    $('status_history_tab').removeClassName("noncurrent");
    $('status_history_tab').addClassName("current");
  }
  if (open == 'annotation_tab') {
    Element.show('annotation');
    $('annotation_tab').removeClassName("noncurrent");
    $('annotation_tab').addClassName("current");
  }
  if (open == 'tag_tab') {
    Element.show('tags_box');
    $('tag_tab').removeClassName("noncurrent");
    $('tag_tab').addClassName("current");
  }
}

function closeRunLaneTagForm() {
  var form_div = $('run_lane_tag_form');
  form_div.hide();
}
