; docformat = 'rst'
;
; NAME:
;       MrPlot__Define
;
;*****************************************************************************************
;   Copyright (c) 2013, Matthew Argall                                                   ;
;   All rights reserved.                                                                 ;
;                                                                                        ;
;   Redistribution and use in source and binary forms, with or without modification,     ;
;   are permitted provided that the following conditions are met:                        ;
;                                                                                        ;
;       * Redistributions of source code must retain the above copyright notice,         ;
;         this list of conditions and the following disclaimer.                          ;
;       * Redistributions in binary form must reproduce the above copyright notice,      ;
;         this list of conditions and the following disclaimer in the documentation      ;
;         and/or other materials provided with the distribution.                         ;
;       * Neither the name of the <ORGANIZATION> nor the names of its contributors may   ;
;         be used to endorse or promote products derived from this software without      ;
;         specific prior written permission.                                             ;
;                                                                                        ;
;   THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY  ;
;   EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES ;
;   OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT  ;
;   SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,       ;
;   INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED ;
;   TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR   ;
;   BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN     ;
;   CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN   ;
;   ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH  ;
;   DAMAGE.                                                                              ;
;*****************************************************************************************
;
; PURPOSE:
;+
;   The purpose of this method is to create an object out of the cgPlot routine.
;
; :Examples:
;   Plot an Nx2 array as two line plots on a single axis.
;       x = findgen(101)/100
;       y = sin(2*!pi*x)
;       z = cos(2*!pi*x)
;       a = obj_new('MrPlot', x, [[y],[z]], DIMENSION=2, TITLE='Sin(x) & Cos(x)', $
;                                   COLOR=['black', 'blue'], XTITLE='Time (s)', $
;                                   YTITLE='Amplitude', /DRAW)
;       obj_destroy, a
;
; :Author:
;   Matthew Argall::
;       University of New Hampshire
;       Morse Hall, Room 113
;       8 College Rd.
;       Durham, NH, 03824
;       matthew.argall@wildcats.unh.edu
;
; :Copyright:
;       Matthew Argall 2013
;
; :History:
;   Modification History::
;       05/18/2013  -   Written by Matthew Argall
;       06/28/2013  -   Added the DIMENSION keyword. Removed the AXES and COLORBARS
;                           properties because the former was not being used and the
;                           latter interfered with the COLOR keyword. - MRA
;       07/04/2013  -   Added the COLOR keyword so that each column or row in DIMENSION
;                           can be plotted in a different color. - MRA
;       07/31/2013  -   Added the ConvertCoord method. - MRA
;       08/09/2013  -   Inherit MrIDL_Container - MRA
;       08/10/2013  -   Added the LAYOUT keyword. - MRA
;       08/22/2013  -   Added the NOERASE keyword to Draw. Was forgetting to set the
;                           position property in SetProperty. Fixed. - MRA
;       08/23/2013  -   Added the IsInside method. - MRA
;       08/30/2013  -   Missed the SYMCOLOR keyword. Now included. - MRA
;       09/08/2013  -   Number of default colors now matches the number of dimensions
;                           being plotted. - MRA
;                           PLOT_INDEX keyword in IsAvailable now works. - MRA
;       09/27/2013  -   Use N_Elements instead of N_Params in case `Y` is present but 
;                           undefined. Position and layout properties are now handled
;                           by MrGraphicAtom. Renamed from MrPlotObject to MrPlot. - MRA
;       09/29/2013  -   Ensure that the layout is updated only when a layout keyword is
;                           passed in. - MRA
;       10/07/2013  -   Added the HIDE keyword. - MRA
;       2013/11/17  -   CHARSIZE is now a MrGraphicAtom property. Use _EXTRA instead of
;                           _STRICT_EXTRA in some cases to make setting and getting
;                           properties easier and to reduce list of keywords. - MRA
;       2013/11/20  -   MrIDL_Container and MrGraphicAtom is disinherited. Inherit instead
;                           MrGrAtom and MrLayout. - MRA
;       2013/11/21  -   Added the doOverplot and TF_Overplot methods as well as the
;                           OVERPLOT property. Renamed DRAW to REFRESH. Refreshing is now
;                           done automatically. Call the Refresh method with the DISABLE
;                           keyword set to temporarily turn of Refresh. - MRA
;       2013/11/23  -   Added the SetLayout and Overplot methods. - MRA
;       2013/12/26  -   Accept multiple targets for overplotting. - MRA
;       2014/01/24  -   Added the _OverloadImpliedPrint and _OverloadPrint methods. - MRA
;       2014/03/10  -   Disinherit the MrLayout class, but keep it as an object property.
;                           Added the GetLayout method. Getting a graphics window is
;                           no longer an obscure process. - MRA
;       2014/03/12  -   Only one target can be given for overplotting so that the graphic
;                           has a unique position. - MRA
;       2014/03/25  -   Extracted methods and properties common to all data graphics
;                           objects and put them into MrGrDataAtom__Define. Inherit
;                           said object class. The SetData method is now called from INIT. - MRA
;       2014/03/21  -   SetData was erasing the independent variable when one parameter
;                           was given. Fixed. - MRA
;-
;*****************************************************************************************
;+
;   The purpose of this method is to print information about the object's properties
;   when the PRINT procedure is used.
;-
function MrPlot::_OverloadPrint
    compile_opt strictarr
    
    ;Error handling
    catch, the_error
    if the_error ne 0 then begin
        catch, /cancel
        void = cgErrorMsg()
        return, "''"
    endif
    
    undefined = '<undefined>'
    undefObj = '<NullObject>'
    default = '<IDL_Default>'
    joinStr = '   '
    
    ;First, get the results from the superclasses
    atomKeys = self -> MrGrAtom::_OverloadPrint()
    grKeys = self -> MrGraphicsKeywords::_OverloadPrint()
    layKeys = self.layout -> _OverloadPrint()

    ;Class Properties
    dimension = string('Dimension', '=', self.dimension, FORMAT='(a-26, a-2, i0)')
    nsum      = string('NSum',      '=', self.nsum,      FORMAT='(a-26, a-2, i1)')
    overplot  = string('OverPlot',  '=', self.overplot,  FORMAT='(a-26, a-2, i1)')
    polar     = string('Polar',     '=', self.polar,     FORMAT='(a-26, a-2, i1)')
    xlog      = string('Xlog',      '=', self.xlog,      FORMAT='(a-26, a-2, i1)')
    ylog      = string('YLog',      '=', self.ylog,      FORMAT='(a-26, a-2, i1)')
    ynozero   = string('YNoZero',   '=', self.ynozero,   FORMAT='(a-26, a-2, i1)')
    
    label     = string('Label', '=', "'" + self.label + "'", FORMAT='(a-26, a-2, a0)')
    
    max_value = string('Max_Value', '=', FORMAT='(a-26, a-2)')
    min_value = string('Min_Value', '=', FORMAT='(a-26, a-2)')
    symcolor  = string('SymColor',  '=', FORMAT='(a-26, a-2)')
    target    = string('Target',    '=', FORMAT='(a-26, a-2)')
    
    ;Pointers
    if n_elements(*self.max_value) eq 0 then max_value += default else max_value += string(*self.max_value, FORMAT='(f0)')
    if n_elements(*self.min_value) eq 0 then min_value += default else min_value += string(*self.min_value, FORMAT='(f0)')
    if n_elements(*self.symcolor)  eq 0 then symcolor += "''"     else symcolor  += strjoin(string(*self.symcolor, FORMAT='(a0)'), joinStr)
    if n_elements(*self.target)    eq 0 then target += undefObj else target += strjoin(MrObj_Class(*self.target), joinStr)
    
    ;Put MrPlot properties together
    selfStr = obj_class(self) + '  <' + strtrim(obj_valid(self, /GET_HEAP_IDENTIFIER), 2) + '>'
    plotKeys = [ dimension, $
                 nsum, $
                 overplot, $
                 polar, $
                 xlog, $
                 ylog, $
                 ynozero, $
                 label, $
                 max_value, $
                 min_value, $
                 symcolor, $
                 target $
               ]

    ;Group everything in alphabetical order
    result = [[atomKeys], [grKeys], [layKeys], [transpose(plotKeys)]]
    result = [[selfStr], ['  ' + transpose(result[sort(result)])]]
    
    return, result
end


;+
;   The purpose of this method is to print information about the object's properties
;   when implied print is used.
;-
function MrPlot::_OverloadImpliedPrint
    compile_opt strictarr
    
    ;Error handling
    catch, the_error
    if the_error ne 0 then begin
        catch, /cancel
        void = cgErrorMsg()
        return, "''"
    endif
    
    result = self -> _OverloadPrint()
    
    return, result
end


;+
;   The purpose of this method is to draw the plot in the draw window.
;-
pro MrPlot::Draw, $
NOERASE = noerase
    compile_opt strictarr
    
    ;Error handling
    catch, the_error
    if the_error ne 0 then begin
        catch, /cancel
        void = cgErrorMsg()
        return
    endif

    ;Leave if we are hiding.
    if self.hide then return
    
    ;Get the current color table
    tvlct, r, g, b, /GET

    ;Overplot?
    if self.overplot then begin
        ;Restore target's coordinate system. Make sure that the overplot
        ;is positioned correctly.
        self.target -> RestoreCoords
        position = [!x.window[0], !y.window[0], $
                    !x.window[1], !y.window[1]]
        self.layout -> SetProperty, POSITION=position
    
    ;Draw axes
    endif else begin
        self -> doAxes, NOERASE=noerase
    endelse

    ;Draw the data and save coordinates.
    self -> doOverplot
    self -> doErrorBars
    self -> SaveCoords
    
    ;Restore the color table
    tvlct, r, g, b
end


;+
;   The purpose of this method is to do the actual plotting. Basically, having this here
;   merely to saves space in the Draw method.
;
; :Private:
;-
pro MrPlot::doAxes, $
NOERASE=noerase
    compile_opt strictarr
    on_error, 2

    if n_elements(noerase) eq 0 then noerase = *self.noerase
    self.layout -> GetProperty, CHARSIZE=charsize, POSITION=position

    ;Colors
    ;    - If we are in indexed color mode and indices are LONGS, they must be fixed.
    thisState = cgGetColorState()
    if thisState eq 0 then begin
        axiscolor  = size(*self.axiscolor, /TNAME)  eq 'LONG' ? fix(*self.axiscolor)  : *self.axiscolor
        background = size(*self.background, /TNAME) eq 'LONG' ? fix(*self.background) : *self.background
    endif

    ;Draw the axes.
    plot, *self.indep, *self.dep, /NODATA, $
          ;MrLayout Keywords
          POSITION  =     position, $
          CHARSIZE  =     charsize, $

          ;Graphics Keywords
          MAX_VALUE = *self.max_value, $
          MIN_VALUE = *self.min_value, $
;          NSUM      =  self.nsum, $
          POLAR     =  self.polar, $
          XLOG      =  self.xlog, $
          YLOG      =  self.ylog, $
          YNOZERO   =  self.ynozero, $
            
          ;MrGraphicsKeywords
          COLOR         = cgColor(axiscolor), $
          BACKGROUND    = cgColor(background), $
          CHARTHICK     = *self.charthick, $
;         CLIP          = *self.clip, $
;         COLOR         = *self.color, $
          DATA          =  self.data, $
          DEVICE        =  self.device, $
          NORMAL        =  self.normal, $
          FONT          = *self.font, $
;         NOCLIP        = *self.noclip, $
;         NODATA        = *self.nodata, $
          NOERASE       =       noerase, $
;         PSYM          = *self.psym, $
          SUBTITLE      = *self.subtitle, $
;         SYMSIZE       = *self.symsize, $
;         T3D           = *self.t3d, $
          THICK         = *self.thick, $
          TICKLEN       = *self.ticklen, $
          TITLE         = cgCheckForSymbols(*self.title), $
          XCHARSIZE     = *self.xcharsize, $
          XGRIDSTYLE    = *self.xgridstyle, $
          XMINOR        = *self.xminor, $
          XRANGE        = *self.xrange, $
          XSTYLE        = *self.xstyle, $
          XTHICK        = *self.xthick, $
          XTICK_GET     = *self.xtick_get, $
          XTICKFORMAT   = *self.xtickformat, $
          XTICKINTERVAL = *self.xtickinterval, $
          XTICKLAYOUT   = *self.xticklayout, $
          XTICKLEN      = *self.xticklen, $
          XTICKNAME     = *self.xtickname, $
          XTICKS        = *self.xticks, $
          XTICKUNITS    = *self.xtickunits, $
          XTICKV        = *self.xtickv, $
          XTITLE        = cgCheckForSymbols(*self.xtitle), $
          YCHARSIZE     = *self.ycharsize, $
          YGRIDSTYLE    = *self.ygridstyle, $
          YMINOR        = *self.yminor, $
          YRANGE        = *self.yrange, $
          YSTYLE        = *self.ystyle, $
          YTHICK        = *self.ythick, $
          YTICK_GET     = *self.ytick_get, $
          YTICKFORMAT   = *self.ytickformat, $
          YTICKINTERVAL = *self.ytickinterval, $
          YTICKLAYOUT   = *self.yticklayout, $
          YTICKLEN      = *self.yticklen, $
          YTICKNAME     = *self.ytickname, $
          YTICKS        = *self.yticks, $
          YTICKUNITS    = *self.ytickunits, $
          YTICKV        = *self.ytickv, $
          YTITLE        = cgCheckForSymbols(*self.ytitle), $
          ZCHARSIZE     = *self.zcharsize, $
          ZGRIDSTYLE    = *self.zgridstyle, $
          ZMARGIN       = *self.zmargin, $
          ZMINOR        = *self.zminor, $
          ZRANGE        = *self.zrange, $
          ZSTYLE        = *self.zstyle, $
          ZTHICK        = *self.zthick, $
          ZTICK_GET     = *self.ztick_get, $
          ZTICKFORMAT   = *self.ztickformat, $
          ZTICKINTERVAL = *self.ztickinterval, $
          ZTICKLAYOUT   = *self.zticklayout, $
          ZTICKLEN      = *self.zticklen, $
          ZTICKNAME     = *self.ztickname, $
          ZTICKS        = *self.zticks, $
          ZTICKUNITS    = *self.ztickunits, $
          ZTICKV        = *self.ztickv, $
          ZTITLE        = cgCheckForSymbols(*self.ztitle), $
          ZVALUE        = *self.zvalue
end


;+
;   The purpose of this method is to do the actual plotting. Basically, having this here
;   merely to saves space in the Draw method.
;
; :Private:
;-
pro MrPlot::doErrorBars
    compile_opt strictarr
    on_error, 2

    ;Number of elements
    nXPlus  = n_elements(*self.err_xplus)
    nXMinus = n_elements(*self.err_xminus)
    nYPlus  = n_elements(*self.err_yplus)
    nYMinus = n_elements(*self.err_yminus)

;---------------------------------------------------------------------
; X Error ////////////////////////////////////////////////////////////
;---------------------------------------------------------------------
    if nXPlus gt 0 || nXMinus gt 0 then begin
        width     = self.err_width / 2 * (!y.window[1] - !y.window[0])
        err_width = convert_coord([0, 0], [-width, width], /NORMAL, /TO_DATA)
        err_width = abs(reform(err_width[1,*]))
        err_width = err_width[1] - err_width[0]
        err_color = cgColor(*self.err_color)
        
    ;---------------------------------------------------------------------
    ; X-PLUS /////////////////////////////////////////////////////////////
    ;---------------------------------------------------------------------
        if nXPlus gt 0 then begin
            for i = 0, nXPlus - 1 do begin
                x     = (*self.indep)[i]
                y     = (*self.dep)[i]
                xplus = x + (*self.err_xplus)[i]
                
                ;Draw the plus part
                plots, [x, xplus, xplus,          xplus], $
                       [y, y,     y-err_width, y+err_width], $
                       COLOR  =      err_color, $
                       NOCLIP = self.err_noclip, $
                       THICK  = self.err_thick
            endfor
        endif
        
    ;---------------------------------------------------------------------
    ; X-MINUS ////////////////////////////////////////////////////////////
    ;---------------------------------------------------------------------
        if nXMinus gt 0 then begin
            for i = 0, nXMinus - 1 do begin
                x      = (*self.indep)[i]
                y      = (*self.dep)[i]
                xminus = x - (*self.err_xminus)[i]
                
                ;Draw the plus part
                plots, [x, xminus, xminus,         xminus], $
                       [y, y,      y-err_width, y+err_width], $
                       COLOR  =      err_color, $
                       NOCLIP = self.err_noclip, $
                       THICK  = self.err_thick
            endfor
        endif
    endif
    
;---------------------------------------------------------------------
; Y Error ////////////////////////////////////////////////////////////
;---------------------------------------------------------------------
    if nYPlus gt 0 || nYMinus gt 0 then begin
        width     = self.err_width / 2 * (!x.window[1] - !x.window[0])
        err_width = convert_coord([-width, width], [0, 0], /NORMAL, /TO_DATA)
        err_width = abs(reform(err_width[0,*]))
        err_width = err_width[1] - err_width[0]
        err_color = cgColor(*self.err_color)
        
    ;---------------------------------------------------------------------
    ; Y-PLUS /////////////////////////////////////////////////////////////
    ;---------------------------------------------------------------------
        if nYPlus gt 0 then begin
            for i = 0, nYPlus - 1 do begin
                x     = (*self.indep)[i]
                y     = (*self.dep)[i]
                yplus = y + (*self.err_yplus)[i]
                
                ;Draw the plus part
                plots, [x, x,      x-err_width, x+err_width], $
                       [y, yplus,  yplus,          yplus], $
                       COLOR  =      err_color, $
                       NOCLIP = self.err_noclip, $
                       THICK  = self.err_thick
            endfor
        endif
        
    ;---------------------------------------------------------------------
    ; Y-MINUS ////////////////////////////////////////////////////////////
    ;---------------------------------------------------------------------
        if nYMinus gt 0 then begin
            for i = 0, nYMinus - 1 do begin
                x      = (*self.indep)[i]
                y      = (*self.dep)[i]
                yminus = y - (*self.err_yminus)[i]
                
                ;Draw the plus part
                plots, [x, x,      x-err_width, x+err_width], $
                       [y, yminus, yminus,         yminus], $
                       COLOR  =      err_color, $
                       NOCLIP = self.err_noclip, $
                       THICK  = self.err_thick
            endfor
        endif
    endif

end


;+
;   The purpose of this method is to do the actual overplotting. Basically, having this
;   here merely to saves space in the Draw method.
;
; :Private:
;-
pro MrPlot::doOverplot

    catch, theerror
    if theerror ne 0 then begin
        catch, /cancel
        void = cgErrorMsg()
        return
    endif
    
    ;Linestyle for plotting
    linestyle = MrLineStyle(*self.linestyle)
    if linestyle eq 6 then return
    
;---------------------------------------------------------------------
; Single Overplot ////////////////////////////////////////////////////
;---------------------------------------------------------------------
    
    ;Get the dimensions of the independent variable.
    if self.dimension eq 0 then begin
        ;Check the symbol to be used
        ;   - If linestyle = 6 (None), then return
        linestyle = MrLineStyle(*self.linestyle)
        if linestyle eq 6 then return

        ;Overplot the data
        oplot, *self.indep, *self.dep, $
               CLIP          = *self.clip, $
               COLOR         = cgColor(*self.color), $
               LINESTYLE     =       linestyle, $
               NOCLIP        = *self.noclip, $
               MAX_VALUE     = *self.max_value, $
               MIN_VALUE     = *self.min_value, $
               NSUM          =  self.nsum, $
               POLAR         =  self.polar, $
               T3D           = *self.t3d, $
               THICK         = *self.thick, $
               ZVALUE        = *self.zvalue
        RETURN
    endif

;---------------------------------------------------------------------
; Multiple Overplots /////////////////////////////////////////////////
;---------------------------------------------------------------------
    ;Get number of elements to make cyclic
    nColor     = n_elements(*self.color)
    nLineStyle = n_elements(*self.linestyle)
    nPSym      = n_elements(*self.psym)
    nSymColor  = n_elements(*self.symcolor)
    nSymSize   = n_elements(*self.symsize)
    nThick     = n_elements(*self.thick)

    ;Plot each vector of data.
    dims = size(*self.dep, /DIMENSIONS)
    iDim = self.dimension eq 1 ? 1 : 0
    for j = 0, dims[iDim]-1 do begin
        ;Get the symbol and linestyle
        color     = cgColor((*self.color)[j mod nColor])
        linestyle = MrLineStyle((*self.linestyle)[j mod nLineStyle])
        if linestyle eq 6 then continue

        case self.dimension of
            1: oplot, *self.indep, (*self.dep)[*,j], $
                      CLIP          =  *self.clip, $
                      COLOR         =        color, $
                      LINESTYLE     =        linestyle, $
                      MAX_VALUE     =  *self.max_value, $
                      MIN_VALUE     =  *self.min_value, $
                      NOCLIP        =  *self.noclip, $
                      NSUM          =   self.nsum, $
                      POLAR         =   self.polar, $
                      T3D           =  *self.t3d, $
                      THICK         = (*self.thick)[j     mod nThick], $
                      ZVALUE        =  *self.zvalue
                        
            2: oplot, *self.indep, (*self.dep)[j,*], $
                      CLIP          =  *self.clip, $
                      COLOR         =        color, $
                      LINESTYLE     =        linestyle, $
                      MAX_VALUE     =  *self.max_value, $
                      MIN_VALUE     =  *self.min_value, $
                      NOCLIP        =  *self.noclip, $
                      NSUM          =   self.nsum, $
                      POLAR         =   self.polar, $
                      PSYM          =        psym, $
                      SYMSIZE       = (*self.symsize)[j   mod nSymSize], $
                      T3D           =  *self.t3d, $
                      THICK         = (*self.thick)[j     mod nThick], $
                      ZVALUE        =  *self.zvalue
        endcase
    endfor
END


;+
;   For lines and symbols to have different colors, they must be plotted separately.
;   This method draws the symbols.
;
; :Private:
;-
pro MrPlot::doSymbols

    catch, theerror
    if theerror ne 0 then begin
        catch, /cancel
        void = cgErrorMsg()
        return
    endif
    
;---------------------------------------------------------------------
; Single Dimension ///////////////////////////////////////////////////
;---------------------------------------------------------------------
    
    ;Get the dimensions of the independent variable.
    if self.dimension eq 0 then begin
        ;Check the symbol to be used
        ;   - If PSym = 0 (None) then return
        psym = cgSymCat(*self.psym)
        if psym eq 0 $
            then return $
            else psym = abs(psym)

        ;Uniform symbols
        if n_elements(*self.symcolor) le 1 then begin
            ;Plot all symbols.
            oplot, *self.indep, *self.dep, $
                      CLIP          = *self.clip, $
                      COLOR         =  cgColor(symcolor), $
                      MAX_VALUE     = *self.max_value, $
                      MIN_VALUE     = *self.min_value, $
                      NOCLIP        = *self.noclip, $
                      NSUM          =  self.nsum, $
                      POLAR         =  self.polar, $
                      PSYM          =       psym, $
                      SYMSIZE       = *self.symsize, $
                      T3D           = *self.t3d, $
                      THICK         = *self.symthick, $
                      ZVALUE        = *self.zvalue
        
        ;Unique symbols
        endif else begin
            nColors = n_elements(*self.symcolor)
        
            ;Step through each point
            for i = 0, n_elements(*self.dep) do begin
                symcolor = cgColor((*self.symcolor)[i mod nColors])
                
                ;Draw the point.
                plots, (*self.indep), (*self.dep), $
                       COLOR =       symcolor, $
                       CLIP  = *self.clip, $
                       THICK =  self.symthick
            endfor
        endelse
        
        return
    endif

;---------------------------------------------------------------------
; Multiple Dimensions ////////////////////////////////////////////////
;---------------------------------------------------------------------
    ;Get number of elements to make cyclic
    nColor     = n_elements(*self.color)
    nLineStyle = n_elements(*self.linestyle)
    nPSym      = n_elements(*self.psym)
    nSymColor  = n_elements(*self.symcolor)
    nSymSize   = n_elements(*self.symsize)
    nThick     = n_elements(*self.thick)

    ;Plot each vector of data.
    dims = size(*self.dep, /DIMENSIONS)
    iDim = self.dimension eq 1 ? 1 : 0
    for j = 0, dims[iDim]-1 do begin
        ;Get the symbol and its color
        color     = cgColor((*self.symcolor)[j mod nColor])
        psym      = cgSymCat((*self.psym)[j mod nPSym])

        ;Skip if PSYM = 0 (None)
        if psym eq 0 then continue
        psym = abs(psym)

        ;Draw the symbols.
        case self.dimension of
            1: oplot, *self.indep, (*self.dep)[*,j], $
                      CLIP          =  *self.clip, $
                      COLOR         =        symcolor, $
                      MAX_VALUE     =  *self.max_value, $
                      MIN_VALUE     =  *self.min_value, $
                      NOCLIP        =  *self.noclip, $
                      NSUM          =   self.nsum, $
                      POLAR         =   self.polar, $
                      PSYM          =        psym, $
                      SYMSIZE       = (*self.symsize)[j  mod nSymSize], $
                      T3D           =  *self.t3d, $
                      THICK         = (*self.symthick)[j mod nThick], $
                      ZVALUE        =  *self.zvalue
                        
            2: oplot, *self.indep, (*self.dep)[j,*], $
                      CLIP          =  *self.clip, $
                      COLOR         =        color, $
                      LINESTYLE     =        linestyle, $
                      MAX_VALUE     =  *self.max_value, $
                      MIN_VALUE     =  *self.min_value, $
                      NOCLIP        =  *self.noclip, $
                      NSUM          =   self.nsum, $
                      POLAR         =   self.polar, $
                      PSYM          =        psym, $
                      SYMSIZE       = (*self.symsize)[j   mod nSymSize], $
                      T3D           =  *self.t3d, $
                      THICK         = (*self.thick)[j     mod nThick], $
                      ZVALUE        =  *self.zvalue
        endcase
    endfor
END
 

;+
;   The purpose of this method is to retrieve data
;
; :Calling Sequence:
;       myGraphic -> SetData, y
;       myGraphic -> SetData, x, y
;
; :Params:
;       X:              out, required, type=numeric array
;                       If this is the only argument, the dependent variable data is
;                           returned. If `Y` is also present, X will be the independent
;                           variable's data.
;       Y:              out, optional, type=numeric array
;                       If present, the dependent variable's data will be returned
;-
pro MrPlot::GetData, x, y, $
ERR_XMINUS = err_xminus, $
ERR_XPLUS = err_xplus, $
ERR_YMINUS = err_yminus, $
ERR_YPLUS = err_yplus
    compile_opt strictarr
    
    ;Error handling
    catch, the_error
    if the_error ne 0 then begin
        catch, /cancel
        void = cgErrorMsg()
        return
    endif
    
    ;Retrieve the data
    case n_params() of
        1: x = *self.dep
        2: begin
            x = *self.indep
            y = *self.dep
        endcase
        else: message, 'Incorrect number of parameters.'
    endcase
    
    ;Error bars
    if arg_present(err_xminus) then err_xminus = *self.err_xminus
    if arg_present(err_xplus)  then err_xplus  = *self.err_xplus
    if arg_present(err_yminus) then err_yminus = *self.err_yminus
    if arg_present(err_yplus)  then err_yplus  = *self.err_yplus
end


;+
;   The purpose of this method is to retrieve object properties
;
; :Keywords:
;       DIMENSION:          in, optional, type=int
;                           The dimension over which to plot.
;       INIT_XRANGE:        out, optional, type=fltarr(2)
;                           The initial state of the XRANGE keyword. This is used to reset
;                               the zoom to its original state.
;       INIT_YRANGE:        out, optional, type=fltarr(2)
;                           The initial state of the YRANGE keyword. This is used to reset
;                               the zoom to its original state.
;       LABEL:              out, optional, type=string
;                           A label is similar to a plot title, but it is aligned to the
;                               left edge of the plot and is written in hardware fonts.
;                               Use of the label keyword will suppress the plot title.
;       NSUM:               out, optional, type=integer
;                           The presence of this keyword indicates the number of data
;                               points to average when plotting.
;       POLAR:              out, optional, type=boolean
;                           Indicates that X and Y are actually R and Theta and that the
;                               plot is in polar coordinates.
;       YNOZERO:            out, optional, type=boolean, default=0
;                           Inhibit setting the y  axis value to zero when all Y > 0 and
;                               no explicit minimum is set.
;       _REF_EXTRA:         out, optional, type=any
;                           Keyword accepted by the superclasses are also accepted for
;                               keyword inheritance.
;-
pro MrPlot::GetProperty, $
DIMENSION = dimension, $
ERR_NOCLIP = err_noclip, $
ERR_COLOR = err_color, $
ERR_THICK = err_thick, $
ERR_WIDTH = err_width, $
INIT_XRANGE = init_xrange, $
INIT_YRANGE = init_yrange, $
NSUM = nsum, $
POLAR = polar, $
SYMCOLOR = symcolor, $
YNOZERO = ynozero, $
_REF_EXTRA = extra
    compile_opt strictarr
    
    ;Error handling
    catch, the_error
    if the_error ne 0 then begin
        catch, /cancel
        void = cgErrorMsg()
        return
    endif
    
    ;Get Properties
    if arg_present(dimension)   then dimension   =  self.dimension
    if arg_present(init_xrange) then init_xrange =  self.init_xrange
    if arg_present(init_yrange) then init_yrange =  self.init_yrange
    if arg_present(label)       then label       =  self.label
    if arg_present(err_color)   then err_color   = *self.err_color
    if arg_present(err_noclip)  then err_noclip  =  self.err_noclip
    if arg_present(err_thick)   then err_thick   =  self.err_thick
    if arg_present(err_width)   then err_width   =  self.err_width
    if arg_present(symcolor)  and n_elements(*self.symcolor)  ne 0 then symcolor = *self.symcolor
    if arg_present(nsum)      and n_elements( self.nsum)      ne 0 then nsum      =  self.nsum
    if arg_present(polar)     and n_elements( self.polar)     ne 0 then polar     =  self.polar
    if arg_present(ynozero)   and n_elements( self.ynozero)   ne 0 then ynozero   = *self.ynozero

    ;Get all of the remaining keywords from MrGrDataAtom
    if n_elements(extra) gt 0 then self -> MrGrDataAtom::GetProperty, _EXTRA=extra
end


;+
;   The purpose of this method is to set data
;
; :Calling Sequence:
;       myGraphic -> SetData, y
;       myGraphic -> SetData, x, y
;
; :Params:
;       X:              in, required, type=numeric array
;                       If this is the only argument, then X represents the dependent
;                           variable data. If `Y` is also given, then X represents the
;                           independent variable data.
;       Y:              in, optional, type=numeric array
;                       The dependent variable data.
;-
pro MrPlot::SetData, x, y, $
ERR_XMINUS = err_xminus, $
ERR_XPLUS = err_xplus, $
ERR_YMINUS = err_yminus, $
ERR_YPLUS = err_yplus
    compile_opt strictarr
    
    ;Error handling
    catch, the_error
    if the_error ne 0 then begin
        catch, /cancel
        void = cgErrorMsg()
        return
    endif
    
    case n_params() of
        1: begin
            if n_elements(x) eq 0 then $
                message, 'First parameter must contain data.'
        
            ;Was a dimension given?
            if self.dimension ne 0 then begin
                dims = size(x, /DIMENSIONS)
                nPts = dims[self.dimension-1]
            endif else begin
                nPts = n_elements(x)
            endelse
        
            ;Only set the dependent variable if the number
            ;of points has changed.
            if n_elements(*self.indep) ne nPts then indep = lindgen(nPts)
            dep = x
        endcase
        
        2: begin
            ;Dimension given?
            if self.dimension ne 0 then begin
                dims = size(y, /DIMENSIONS)
                nPts = dims[self.dimension-1]
            endif else begin
                nPts = n_elements(y)
            endelse
        
            if nPts ne n_elements(x) then $
                message, 'X and Y have incompatible number of elements.'
            
            indep = x
            dep   = y
        endcase
    endcase

    ;Set Data
    *self.dep = temporary(dep)
    if n_elements(indep)      gt 0 then *self.indep      = temporary(indep)
    if n_elements(err_xplus)  gt 0 then *self.err_xplus  = err_xplus
    if n_elements(err_xminus) gt 0 then *self.err_xminus = err_xminus
    if n_elements(err_yplus)  gt 0 then *self.err_yplus  = err_yplus
    if n_elements(err_yminus) gt 0 then *self.err_yminus = err_yminus

    ;Refresh the graphics window
    self.window -> Draw
end


;+
;   The purpose of this method is to set object properties. 
;
; :Keywords:
;       DIMENSION:          in, optional, type=int
;                           The dimension over which to plot.
;       LABEL:              in, optional, type=string
;                           A label is similar to a plot title, but it is aligned to the
;                               left edge of the plot and is written in hardware fonts.
;                               Use of the label keyword will suppress the plot title.
;       MAX_VALUE:          in, optional, type=float
;                           The maximum value plotted. Any values larger than this are
;                               treated as missing.
;       MIN_VALUE:          in, optional, type=float
;                           The minimum value plotted. Any values smaller than this are
;                               treated as missing.
;       NSUM:               in, optional, type=integer
;                           The presence of this keyword indicates the number of data
;                               points to average when plotting.
;       POLAR:              in, optional, type=boolean
;                           Indicates that X and Y are actually R and Theta and that the
;                               plot is in polar coordinates.
;       POSITION:           in, optional, type=fltarr(4)
;                           A vector of the form [x0, y0, x1, y1] specifying the location
;                               of the lower-left and upper-right corners of the graphic,
;                               in normalized coordinates.
;       XLOG:               in, optional, type=boolean
;                           Indicates that a log scale is used on the x-axis
;       YLOG:               in, optional, type=boolean
;                           Indicates that a log scale is used on the y-axis
;       YNOZERO:            in, optional, type=boolean, default=0
;                           Inhibit setting the y  axis value to zero when all Y > 0 and
;                               no explicit minimum is set.
;       _REF_EXTRA:         in, optional, type=any
;                           Keyword accepted by the MrGrAtom and MrGraphicsKeywords are
;                               also accepted for keyword inheritance.
;-
pro MrPlot::SetProperty, $
CHARSIZE = charsize, $
DIMENSION = dimension, $
ERR_NOCLIP = err_noclip, $
ERR_COLOR = err_color, $
ERR_THICK = err_thick, $
ERR_WIDTH = err_width, $
MAX_VALUE = max_value, $
MIN_VALUE = min_value, $
NSUM = nsum, $
POLAR = polar, $
POSITION = position, $
PSYM = psym, $
SYMCOLOR = symcolor, $
XLOG = xlog, $
YLOG = ylog, $
XSTYLE = xstyle, $          ;Check explicitly so that the 2^0 bit is always set
YNOZERO = ynozero, $
YSTYLE = ystyle, $          ;Check explicitly so that the 2^0 bit is always set
_REF_EXTRA = extra
    compile_opt strictarr
    
    ;Error handling
    catch, the_error
    if the_error ne 0 then begin
        catch, /cancel
        void = cgErrorMsg()
        return
    endif
    
    ;Graphics Properties
    if n_elements(dimension)  ne 0 then  self.dimension  = dimension
    if n_elements(err_color)  ne 0 then *self.err_color  = err_color
    if n_elements(err_noclip) ne 0 then  self.err_noclip = err_noclip
    if n_elements(err_thick)  ne 0 then  self.err_thick  = err_thick
    if n_elements(err_width)  ne 0 then  self.err_width  = err_width
    if n_elements(max_value)  ne 0 then *self.max_value  = max_value
    if n_elements(min_value)  ne 0 then *self.min_value  = min_value
    if n_elements(nsum)       ne 0 then  self.nsum       = nsum
    if n_elements(polar)      ne 0 then  self.polar      = keyword_set(polar)
    if n_elements(symcolor)   ne 0 then *self.symcolor   = symcolor
    if n_elements(xlog)       ne 0 then  self.xlog       = keyword_set(xlog)
    if n_elements(ylog)       ne 0 then  self.ylog       = keyword_set(ylog)
    if n_elements(ynozero)    ne 0 then  self.ynozero    = keyword_set(ynozero)
    if n_elements(xstyle)     ne 0 then *self.xstyle     = ~(xstyle and 1) + xstyle
    if n_elements(ystyle)     ne 0 then *self.ystyle     = ~(ystyle and 1) + ystyle
    if n_elements(position)   gt 0 then  self -> SetLayout, POSITION=position
    if n_elements(charsize)   gt 0 then  self -> SetLayout, CHARSIZE=charsize, UPDATE_LAYOUT=0
    
    ;Symbol
    if n_elements(psym) gt 0 then begin
        if size(psym, /TNAME) eq 'STRING' then begin
            names = cgSymCat(/NAMES)
            void  = isMember(names, psym, /FOLD_CASE, /REMOVE_SPACE, N_NONMEMBERS=nFail, NONMEMBER_INDS=iFail)
            if nFail gt 0 then $
                message, 'PSYM not a valid symbol name: "' + strjoin(names[iFail], '", "') + '".'
        endif
        
        *self.psym = psym
    endif

;---------------------------------------------------------------------
;Superclass Properties ///////////////////////////////////////////////
;---------------------------------------------------------------------
    self -> MrGrDataAtom::SetProperty, _EXTRA=extra
    
    ;Refresh the graphics window
    self.window -> Draw
end


;+
;   Clean up after the object is destroyed -- destroy pointers and object references.
;-
pro MrPlot::cleanup
    compile_opt strictarr
    
    ;Error handling
    catch, the_error
    if the_error ne 0 then begin
        catch, /cancel
        void = cgErrorMsg()
        return
    endif
    
    ;free all pointers
    ptr_free, self.indep
    ptr_free, self.dep
    ptr_free, self.symcolor
    
    ;Cleanup the superclass.
    self -> MrGrDataAtom::CleanUp
end


;+
;   The purpose of this method is to create line plot in a zoomable, resizeable window
;   that contains several analysis options (with more to be added). Only certain features
;   are available at any one time, but all can be selected from the menu bar.
;
; :Params:
;       X:                  in, required, type=any
;                           If Y is given, a vector representing the independent variable
;                               to be plotted. If Y is not given, a vector or array of
;                               representing the dependent variable to be plotted. Each
;                               column of X will then be overplotted as individual vectors
;                               in the same set of axes.
;       Y:                  in, optional, type=any
;                           A vector or array of representing the dependent variable to be
;                               plotted. Each column of Y will then be overplotted
;                               as individual vectors in the same set of axes.
;
; :Keywords:
;       COLOR:              in, optional, type=string/strarr, default='opposite'
;                           Color of the line plots. If `DIMENSION` is used, there must
;                               be one color per component.
;       DIMENSION:          in, optional, type=int, default=0
;                           The dimension over which to plot. As an example, say `Y` is
;                               an N1xN2 array and settind DIMENSION=2. Then, N1 plots
;                               will be overplotted on top of each other, one for each
;                               DATA[i,*]. If DIMENSION=0, then a single plot of all
;                               points will be made.
;       MAX_VALUE:          in, optional, type=float
;                           The maximum value plotted. Any values larger than this are
;                               treated as missing.
;       MIN_VALUE:          in, optional, type=float
;                           The minimum value plotted. Any values smaller than this are
;                               treated as missing.
;       POLAR:              in, optional, type=boolean
;                           Indicates that X and Y are actually R and Theta and that the
;                               plot is in polar coordinates.
;       OVERPLOT:           in, optional, type=boolean/object
;                           Set equal to 1 or to a graphic object refrence. If set to 1,
;                               the plot will be overploted onto an existing graphic in the
;                               current window. If a graphic is selected it will be the
;                               target. If no graphics are selected, the highest ordered
;                               graphic will be the target. If no window is open, a new
;                               window will be created.If set to a graphic's object
;                               refrece to use that graphic as the target of the overplot.
;       XLOG:               in, optional, type=boolean
;                           Indicates that a log scale is used on the x-axis
;       XRANGE:             in, optional, type=fltarr(2), default=[min(`X`)\, max(`X`)]
;                           The x-axis range over which the data will be displayed.
;       YLOG:               in, optional, type=boolean
;                           Indicates that a log scale is used on the y-axis
;       YNOZERO:            in, optional, type=boolean, default=0
;                           Inhibit setting the y  axis value to zero when all Y > 0 and
;                               no explicit minimum is set.
;       YRANGE:             in, optional, type=fltarr(2), default=[min(`X`)\, max(`X`)]
;                           The y-axis range over which the data will be displayed.
;       _REF_EXTRA:         in, optional, type=any
;                           Keywords accepted by the any of the superclasses are also
;                               accepted for keyword inheritcance.
;-
function MrPlot::init, x, y, $
;MrPlot Keywords
AXISCOLOR = axiscolor, $
BACKGROUND = background, $
COLOR = color, $
CURRENT = current, $
DIMENSION = dimension, $
ERR_COLOR = err_color, $
ERR_NOCLIP = err_noclip, $
ERR_THICK = err_thick, $
ERR_WIDTH = err_width, $
ERR_XMINUS = err_xminus, $
ERR_XPLUS = err_xplus, $
ERR_YMINUS = err_yminus, $
ERR_YPLUS = err_yplus, $
HIDE = hide, $
LAYOUT = layout, $
LINESTYLE = linestyle, $
MAX_VALUE = max_value, $
MIN_VALUE = min_value, $
NAME = name, $
NSUM = nsum, $
OVERPLOT = overplot, $
POLAR = polar, $
POSITION = position, $
SYMCOLOR = symcolor, $
SYMSIZE = symsize, $
THICK = thick, $
TITLE = title, $
XLOG = xlog, $
XRANGE = xrange, $
XTITLE = xtitle, $
YLOG = ylog, $
YNOZERO = ynozero, $
YRANGE = yrange, $
YTITLE = ytitle, $
_REF_EXTRA = extra
    compile_opt strictarr

    ;Error handling
    catch, the_error
    if the_error ne 0 then begin
        catch, /cancel
        void = cgErrorMsg()
        return, 0
    endif

;---------------------------------------------------------------------
; Superclasses ///////////////////////////////////////////////////////
;---------------------------------------------------------------------

    ;Sets up window -- Must be done before calling any method that subsequently
    ;                  calls the draw method.
    success = self -> MrGrDataAtom::Init(CURRENT=current, HIDE=hide, LAYOUT=layout, $
                                         NAME=name, OVERPLOT=overplot, POSITION=position, $
                                         REFRESH=refresh, WINDOW_TITLE=window_title, $
                                         _EXTRA=extra)
    if success eq 0 then message, 'Unable to initialize superclass MrGrDataAtom.'

;---------------------------------------------------------------------
; Defaults and Heap //////////////////////////////////////////////////
;---------------------------------------------------------------------
    polar      = keyword_set(polar)
    ynozero    = keyword_set(ynozero)
    err_noclip = n_elements(err_noclip) eq 0 ? 1 : keyword_set(err_noclip)
    if n_elements(dimension) eq 0 then dimension = 0
    if n_elements(err_thick) eq 0 then err_thick = 1.0
    if n_elements(err_width) eq 0 then err_width = 0.01
    if n_elements(nSum)      eq 0 then nSum      = 0
    if n_elements(psym)      eq 0 then psym      = 'None'
    if n_elements(linestyle) eq 0 then linestyle = '-'
    if n_elements(symsize)   eq 0 then symsize   = 1.0
    if n_elements(thick)     eq 0 then thick     = 1.0
    if n_elements(title)     eq 0 then title     = ''
    if n_elements(xtitle)    eq 0 then xtitle    = ''
    if n_elements(ytitle)    eq 0 then ytitle    = ''
    if n_elements(ztitle)    eq 0 then ztitle    = ''

    ;Allocate Heap
    self.indep      = ptr_new(/ALLOCATE_HEAP)
    self.dep        = ptr_new(/ALLOCATE_HEAP)
    self.symcolor   = ptr_new(/ALLOCATE_HEAP)
    self.err_color  = ptr_new(/ALLOCATE_HEAP)
    self.err_xminus = ptr_new(/ALLOCATE_HEAP)
    self.err_xplus  = ptr_new(/ALLOCATE_HEAP)
    self.err_yminus = ptr_new(/ALLOCATE_HEAP)
    self.err_yplus  = ptr_new(/ALLOCATE_HEAP)
    
;---------------------------------------------------------------------
;Dependent and Independent Variables /////////////////////////////////
;---------------------------------------------------------------------
    ;Set the data    
    self.dimension = dimension
    case n_params() of
        1: self -> SetData, x,    ERR_XMINUS=err_xminus, ERR_XPLUS=err_xplus, $
                                  ERR_YMINUS=err_yminus, ERR_YPLUS=err_yplus
        2: self -> SetData, x, y, ERR_XMINUS=err_xminus, ERR_XPLUS=err_xplus, $
                                  ERR_YMINUS=err_yminus, ERR_YPLUS=err_yplus
        else: message, 'Incorrect number of parameters.'
    endcase
    
;---------------------------------------------------------------------
; Colors /////////////////////////////////////////////////////////////
;---------------------------------------------------------------------
        
    ;Number of defaults to use.
    ;   - There are at most two dimensions.
    ;   -   dimension=2
    depDims = size(*self.dep, /DIMENSIONS)
    if self.dimension eq 0 $
        then nDefaults = 1 $
        else nDefaults = depDims[2-self.dimension]
    
    ;Colors
    axiscolor  = MrDefaultColor(axiscolor,  TRADITIONAL=traditional)
    background = MrDefaultColor(background, TRADITIONAL=traditional, /BACKGROUND)
    colors     = MrDefaultColor(color,      NCOLORS=nDefaults)
    err_color  = MrDefaultColor(err_color,  TRADITIONAL=traditional)
    symcolor   = MrDefaultColor(symcolor,   NCOLORS=nDefaults)
    
;---------------------------------------------------------------------
; SetProperties //////////////////////////////////////////////////////
;---------------------------------------------------------------------
    self -> SetProperty, AXISCOLOR = axiscolor, $
                         BACKGROUND = background, $
                         COLOR = colors, $
                         DIMENSION = dimension, $
                         ERR_NOCLIP = err_noclip, $
                         ERR_THICK = err_thick, $
                         ERR_WIDTH = err_width, $
                         LINESTYLE = linestyle, $
                         MAX_VALUE = max_value, $
                         MIN_VALUE = min_value, $
                         NSUM = nsum, $
                         PSYM = psym, $
                         POLAR = polar, $
                         SYMCOLOR = symcolor, $
                         SYMSIZE = symsize, $
                         THICK = thick, $
                         TITLE = title, $
                         XLOG = xlog, $
                         XRANGE = xrange, $
                         XTITLE = xtitle, $
                         YLOG = ylog, $
                         YNOZERO = ynozero, $
                         YRANGE = yrange, $
                         YTITLE = ytitle, $
                         ZTITLE = ztitle

    ;Make sure the x- and y-style keywords have the 2^0 bit set to force
    ;exact axis ranges.    
    if n_elements(*self.xstyle) eq 0 $
        then *self.xstyle = 1 $
        else *self.xstyle += ~(*self.xstyle and 1)
        
    if n_elements(*self.ystyle) eq 0 $
        then *self.ystyle = 1 $
        else *self.ystyle += ~(*self.ystyle and 1)

    ;Refresh the graphics?
    if refresh then self -> Refresh

    return, 1
end


;+
;   Object class definition
;
; :Params:
;       CLASS:          out, optional, type=structure
;                       The class definition structure.
;-
pro MrPlot__define, class
    compile_opt strictarr
    
    class = { MrPlot, $
              inherits MrGrDataAtom, $
             
              ;Data Properties
              indep:      ptr_new(), $          ;independent variable
              dep:        ptr_new(), $          ;dependent variable
              err_xminus: ptr_new(), $
              err_xplus:  ptr_new(), $
              err_yminus: ptr_new(), $
              err_yplus:  ptr_new(), $
             
              ;Graphics Properties
              dimension:  0, $                   ;The over which plots will be made
              err_noclip: 0B, $
              err_color:  ptr_new(), $
              err_thick:  0.0, $
              err_width:  0.0, $
              polar:      0B, $                  ;create a polar plot?
              nsum:       0L, $                  ;number of points to average when plotting
              symcolor:   ptr_new(), $           ;color of each symbol
              ynozero:    0B, $                  ;do not make ymin=0
             
              ;Initial Properties
              init_xrange: dblarr(2), $         ;Initial y-range
              init_yrange: dblarr(2) $          ;Initial x-range
            }
end