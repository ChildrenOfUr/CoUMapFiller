part of CoUMapFiller;

class ReportWindow
{
	static Element create()
	{
		DivElement reportWindow = new DivElement()
			..id="ReportWindow"..className="PopWindow";
		
		DivElement header = new DivElement()..className = "PopWindowHeader handle";
        DivElement title = new DivElement()
        	..id="ReportTitle"..text = "Report Street";
        SpanElement close = new SpanElement()
        	..id="CloseReport"..className="fa fa-times fa-lg red PopCloseEmblem";
        header..append(title)..append(close);
        
		DivElement text = new DivElement()
			..id="ReportText"..text = "What would you like to submit a report for?";
		
		FormElement form = new FormElement();
		DivElement brokenParent = new DivElement();
		RadioButtonInputElement broken = new RadioButtonInputElement()
			..id="BrokenRadio"..name="reason"..attributes['reason']="Broken"..checked=true;
		LabelElement brokenLabel = new LabelElement()
			..text="Street is broken/won't load"..attributes['for']="BrokenRadio";
		brokenParent..append(broken)..append(brokenLabel);
		DivElement vandalizedParent = new DivElement();
		RadioButtonInputElement vandalized = new RadioButtonInputElement()
        	..id="VandalizedRadio"..name="reason"..attributes['reason']="Vandalized";
		LabelElement vandalizedLabel = new LabelElement()
        	..text="Street has been vandalized"..attributes['for']="VandalizedRadio";
		vandalizedParent..append(vandalized)..append(vandalizedLabel);
		form..append(brokenParent)..append(vandalizedParent);
		
		TextAreaElement detailsBox = new TextAreaElement()
			..id="ReportDetails"..placeholder="Please describe the problem";
		
		DivElement submit = new DivElement()
			..id="ReportSubmit"..className="button shadow"..text="Submit";
		
		reportWindow..append(header)..append(text)..append(form)..append(detailsBox)..append(submit);
		
		
		detailsBox.onFocus.listen((_)
		{
			playerInput.ignoreKeys = true;
		});
		detailsBox.onBlur.listen((_)
		{
			playerInput.ignoreKeys = false;
		});
        		
		close.onClick.first.then((_) => destroy());
		submit.onClick.listen((_)
		{
			if(tsid == null)
			{
				destroy();
				showToast("No street loaded");
				return;
			}
			
			String reason = broken.checked?"Broken":"Vandalized";
			String details = detailsBox.value;
			String address = "$serverAddress/reportStreet?tsid=$tsid&reason=$reason&details=$details";
			HttpRequest.getString(address).then((String response)
        	{
				if(response == "OK")
				{
					showToast("Thanks for the report");
					destroy();
					new Timer(new Duration(milliseconds:1500), () => loadRandomStreet());
				}
				else
					showToast("Problem sending report");
        	});
		});
		
		return reportWindow;
	}
	
	static void destroy()
	{
		DivElement reportWindow = querySelector("#ReportWindow");
		if(reportWindow != null)
			reportWindow.remove();
	}
}