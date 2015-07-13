; ------------------------------------------
; Script     : test-1.ncl
; Created on : 13.07.2015 09:35:43
; Author     : Robert Redl
; ------------------------------------------
; Description:
;   test of the feature detection module
; ------------------------------------------

external LIBFEATURE "libfeature.so"

; plot input data or features
procedure plot(data, filename, nfeature)
begin
    ptype = "png"
    ptype@wkWidth = 300
    ptype@wkHeight = 300
    wks = gsn_open_wks(ptype, filename)

    res = True
    res@gsnMaximize             = True
    res@cnFillOn                = True
    res@cnLinesOn               = False
    res@cnFillMode              = "RasterFill"
    if (nfeature .gt. 0) then
        res@cnLevelSelectionMode    = "ExplicitLevels"
        res@cnLevels                = ispan(1, nfeature, 1)
        gsn_define_colormap(wks, "wind_17lev")
    else
        gsn_define_colormap(wks, "gsltod")
    end if
    plt = gsn_csm_contour(wks, data, res)
    delete(wks)
end

begin
    ; load test data
    infile = addfile("etc/test-1.nc", "r")
    data = infile->image
    delete(infile)

    ; find features in test data
    dims = dimsizes(data)
    feat = new (dims, float)
    feat@_FillValue = data@_FillValue
    LIBFEATURE::detect_features(dims(0), dims(1), data, feat, 0.5, data@_FillValue)

    ; show results
    nfeature = toint(max(feat))
    print("number of features: "+ nfeature)
    print("sizes of features:")
    do i = 1, nfeature
        points_in_feature := ind(ndtooned(feat) .eq. i)
        print("    -> feature " + i + ": " + dimsizes(points_in_feature))
    end do
    
    ; plot input and output arrays
    plot(data, "etc/test-1-input", 0)
    plot(feat, "etc/test-1-output", nfeature)
end