VERSION 5.00
Begin VB.UserControl pdMetadataExport 
   Appearance      =   0  'Flat
   BackColor       =   &H80000005&
   ClientHeight    =   4650
   ClientLeft      =   0
   ClientTop       =   0
   ClientWidth     =   5250
   DrawStyle       =   5  'Transparent
   BeginProperty Font 
      Name            =   "Tahoma"
      Size            =   8.25
      Charset         =   0
      Weight          =   400
      Underline       =   0   'False
      Italic          =   0   'False
      Strikethrough   =   0   'False
   EndProperty
   HasDC           =   0   'False
   ScaleHeight     =   310
   ScaleMode       =   3  'Pixel
   ScaleWidth      =   350
   ToolboxBitmap   =   "pdMetadataExport.ctx":0000
   Begin PhotoDemon.pdLabel lblInfo 
      Height          =   375
      Index           =   0
      Left            =   0
      Top             =   1200
      Width           =   5055
      _ExtentX        =   8916
      _ExtentY        =   661
      Caption         =   "general metadata settings"
      FontSize        =   12
   End
   Begin PhotoDemon.pdLabel lblTitle 
      Height          =   495
      Left            =   120
      Top             =   0
      Width           =   4935
      _ExtentX        =   8705
      _ExtentY        =   873
      Alignment       =   2
      Caption         =   ""
      FontBold        =   -1  'True
      FontSize        =   12
   End
   Begin PhotoDemon.pdHyperlink hplReviewMetadata 
      Height          =   375
      Left            =   120
      Top             =   600
      Width           =   4935
      _ExtentX        =   8705
      _ExtentY        =   661
      Alignment       =   2
      Caption         =   "click to review this image's metadata"
      RaiseClickEvent =   -1  'True
   End
   Begin PhotoDemon.pdCheckBox chkMetadata 
      Height          =   375
      Left            =   120
      TabIndex        =   0
      Top             =   1680
      Width           =   4935
      _ExtentX        =   8705
      _ExtentY        =   661
      Caption         =   "copy all relevant metadata to the new file"
   End
   Begin PhotoDemon.pdCheckBox chkAnonymize 
      Height          =   375
      Left            =   120
      TabIndex        =   1
      Top             =   2160
      Width           =   4935
      _ExtentX        =   8705
      _ExtentY        =   661
      Caption         =   "erase tags that might be personal (including GPS and location)"
   End
   Begin PhotoDemon.pdLabel lblInfo 
      Height          =   375
      Index           =   1
      Left            =   0
      Top             =   2640
      Visible         =   0   'False
      Width           =   5055
      _ExtentX        =   8916
      _ExtentY        =   661
      Caption         =   ""
      FontSize        =   12
   End
   Begin PhotoDemon.pdCheckBox chkThumbnail 
      Height          =   375
      Left            =   120
      TabIndex        =   2
      Top             =   3120
      Visible         =   0   'False
      Width           =   4935
      _ExtentX        =   8705
      _ExtentY        =   661
      Caption         =   "embed thumbnail image"
      Value           =   0
   End
End
Attribute VB_Name = "pdMetadataExport"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = False
Attribute VB_Exposed = False
'***************************************************************************
'PhotoDemon Metadata Export control group
'Copyright 2016-2016 by Tanner Helland
'Created: 18/March/16
'Last updated: 13/June/16
'Last update: minor code clean-up
'
'This simple "control" is used by various export dialog to expose settings related to metadata handling.
'
'All source code in this file is licensed under a modified BSD license.  This means you may use the code in your own
' projects IF you provide attribution.  For more information, please visit http://photodemon.org/about/license/
'
'***************************************************************************

Option Explicit

'Because VB focus events are wonky, especially when we use CreateWindow within a UC, this control raises its own
' specialized focus events.  If you need to track focus, use these instead of the default VB functions.
Public Event GotFocusAPI()
Public Event LostFocusAPI()

'Copy of the image being saved.  We need to probe this object for things like its current metadata state.
Private m_ImageCopy As pdImage

'Similarly, when setting the relevant pdImage reference, our parent dialog will also notify us of the destination
' file format.  This affects what metadata settings we expose.
Private m_DstFormat As PHOTODEMON_IMAGE_FORMAT

'User control support class.  Historically, many classes (and associated subclassers) were required by each user control,
' but I've since attempted to wrap these into a single master control support class.
Private WithEvents ucSupport As pdUCSupport
Attribute ucSupport.VB_VarHelpID = -1

'Local list of themable colors.  This list includes all potential colors used by this class, regardless of state change
' or internal control settings.  The list is updated by calling the UpdateColorList function.
' (Note also that this list does not include variants, e.g. "BorderColor" vs "BorderColor_Hovered".  Variant values are
'  automatically calculated by the color management class, and they are retrieved by passing boolean modifiers to that
'  class, rather than treating every imaginable variant as a separate constant.)
Private Enum PDME_COLOR_LIST
    [_First] = 0
    PDME_Background = 0
    [_Last] = 0
    [_Count] = 1
End Enum

'Color retrieval and storage is handled by a dedicated class; this allows us to optimize theme interactions,
' without worrying about the details locally.
Private m_Colors As pdThemeColors

'The Enabled property is a bit unique; see http://msdn.microsoft.com/en-us/library/aa261357%28v=vs.60%29.aspx
Public Property Get Enabled() As Boolean
Attribute Enabled.VB_UserMemId = -514
    Enabled = UserControl.Enabled
End Property

Public Property Let Enabled(ByVal newValue As Boolean)
    UserControl.Enabled = newValue
    PropertyChanged "Enabled"
End Property

Public Property Get hWnd() As Long
Attribute hWnd.VB_UserMemId = -515
    hWnd = UserControl.hWnd
End Property

'Container hWnd must be exposed for external tooltip handling
Public Property Get ContainerHwnd() As Long
    ContainerHwnd = UserControl.ContainerHwnd
End Property

'To support high-DPI settings properly, we expose specialized move+size functions
Public Function GetLeft() As Long
    GetLeft = ucSupport.GetControlLeft
End Function

Public Sub SetLeft(ByVal newLeft As Long)
    ucSupport.RequestNewPosition newLeft, , True
End Sub

Public Function GetTop() As Long
    GetTop = ucSupport.GetControlTop
End Function

Public Sub SetTop(ByVal newTop As Long)
    ucSupport.RequestNewPosition , newTop, True
End Sub

Public Function GetWidth() As Long
    GetWidth = ucSupport.GetControlWidth
End Function

Public Sub SetWidth(ByVal newWidth As Long)
    ucSupport.RequestNewSize newWidth, , True
End Sub

Public Function GetHeight() As Long
    GetHeight = ucSupport.GetControlHeight
End Function

Public Sub SetHeight(ByVal newHeight As Long)
    ucSupport.RequestNewSize , newHeight, True
End Sub

Public Sub SetPositionAndSize(ByVal newLeft As Long, ByVal newTop As Long, ByVal newWidth As Long, ByVal newHeight As Long)
    ucSupport.RequestFullMove newLeft, newTop, newWidth, newHeight, True
End Sub

Private Sub ucSupport_GotFocusAPI()
    RaiseEvent GotFocusAPI
End Sub

Private Sub ucSupport_LostFocusAPI()
    RaiseEvent LostFocusAPI
End Sub

Private Sub ucSupport_WindowResize(ByVal newWidth As Long, ByVal newHeight As Long)
    UpdateControlLayout
End Sub

Private Sub chkMetadata_Click()

    If CBool(chkMetadata.Value) Then
        chkAnonymize.Enabled = True
        chkThumbnail.Enabled = True
    Else
        chkAnonymize.Enabled = False
        chkThumbnail.Enabled = False
    End If

End Sub

Private Sub hplReviewMetadata_Click()
    ExifTool.ShowMetadataDialog m_ImageCopy, UserControl.Parent
End Sub

Private Sub UserControl_Initialize()
    
    m_DstFormat = PDIF_UNKNOWN
    
    'Initialize a master user control support class
    Set ucSupport = New pdUCSupport
    ucSupport.RegisterControl UserControl.hWnd, , True
    
'    'I'm still debating the merits of letting the user control the outgoing metadata format.  This can be powerful for
'     formats like JPEG (where multiple metadata formats are available, and it's hard to know what a user "wants"),
'     but it can also get them into trouble if they select an output format that doesn't support the full breadth of
'     tags in the current image.
'
'    'At present, I'm still studying what other software does, to try and get a feel for how others have tackled this,
'     so outgoing metadata formats are still handled silently.

'    btsMetadataFormat.AddItem "automatic", 0
'    btsMetadataFormat.AddItem "IPTC", 1
'    btsMetadataFormat.AddItem "EXIF", 2
'    btsMetadataFormat.AddItem "XMP", 3
        
    'Prep the color manager and load default colors
    Set m_Colors = New pdThemeColors
    Dim colorCount As PDME_COLOR_LIST: colorCount = [_Count]
    m_Colors.InitializeColorList "PDMetadataExport", colorCount
    If Not g_IsProgramRunning Then UpdateColorList
    
    'Update the control size parameters at least once
    UpdateControlLayout
    
End Sub

'At run-time, painting is handled by the support class.  In the IDE, however, we must rely on VB's internal paint event.
Private Sub UserControl_Paint()
    ucSupport.RequestIDERepaint UserControl.hDC
End Sub

Private Sub UserControl_Resize()
    If Not g_IsProgramRunning Then ucSupport.RequestRepaint True
End Sub

Private Sub UserControl_Terminate()
    Set m_ImageCopy = Nothing
End Sub

'Whenever a control property changes that affects control size or layout (including internal changes, like caption adjustments),
' call this function to recalculate the control's internal layout
Private Sub UpdateControlLayout()
    
    'Retrieve DPI-aware control dimensions from the support class
    Dim bWidth As Long, bHeight As Long
    bWidth = ucSupport.GetBackBufferWidth
    bHeight = ucSupport.GetBackBufferHeight
    
    'At present, everything in this control extends the full width of the container
    lblTitle.SetWidth (bWidth - (lblTitle.GetLeft * 2))
    chkMetadata.SetWidth (bWidth - chkMetadata.GetLeft)
    chkAnonymize.SetWidth (bWidth - chkAnonymize.GetLeft)
    hplReviewMetadata.SetWidth (bWidth - (hplReviewMetadata.GetLeft * 2))
    
    '...including format-specific options (which may or may not be visible, depending on the parent format)
    chkThumbnail.SetWidth (bWidth - chkThumbnail.GetLeft)
    
    Dim i As Long
    For i = lblInfo.lBound To lblInfo.UBound
        lblInfo(i).SetWidth (bWidth - (lblInfo(i).GetLeft * 2))
    Next i
                
End Sub

'Before this control does any painting, we need to retrieve relevant colors from PD's primary theming class.  Note that this
' step must also be called if/when PD's visual theme settings change.
Private Sub UpdateColorList()
    m_Colors.LoadThemeColor PDME_Background, "Background", IDE_WHITE
End Sub

'External functions can call this to request a redraw.  This is helpful for live-updating theme settings, as in the Preferences dialog.
Public Sub UpdateAgainstCurrentTheme()
    
    UpdateColorList
    
    ucSupport.SetCustomBackColor m_Colors.RetrieveColor(PDME_Background, Me.Enabled)
    UserControl.BackColor = m_Colors.RetrieveColor(PDME_Background, Me.Enabled)
    
    lblTitle.UpdateAgainstCurrentTheme
    chkMetadata.UpdateAgainstCurrentTheme
    chkAnonymize.UpdateAgainstCurrentTheme
    hplReviewMetadata.UpdateAgainstCurrentTheme
    chkThumbnail.UpdateAgainstCurrentTheme
    
    Dim i As Long
    For i = lblInfo.lBound To lblInfo.UBound
        lblInfo(i).UpdateAgainstCurrentTheme
    Next i
    
    If g_IsProgramRunning Then ucSupport.UpdateAgainstThemeAndLanguage
    
End Sub

'Retrieve the current metadata settings in XML format
Public Function GetMetadataSettings() As String

    Dim cParams As pdParamXML
    Set cParams = New pdParamXML
    
    cParams.AddParam "MetadataExportAllowed", CBool(chkMetadata.Value)
    cParams.AddParam "MetadataAnonymize", CBool(chkAnonymize.Value)
    If IsThumbnailSupported() Then cParams.AddParam "MetadataEmbedThumbnail", CBool(chkThumbnail.Value) Else cParams.AddParam "MetadataEmbedThumbnail", False
    
    'Whenever a new metadata string is generated, we also generate a new temp filename for use with this image.
    ' This file may or may not created (it's required when setting thumbnails, for example), but by setting it at the
    ' image level, we allow any subsequent metadata operations to reuse the same file at their leisure.
    cParams.AddParam "MetadataTempFilename", FileSystem.RequestTempFile()
    
    GetMetadataSettings = cParams.GetParamString

End Function

'Retrieve a stock metadata XML packet that corresponds to "don't write metadata".  This gives the dialog a way to
' forcibly prevent metadata from being written (which we do with web-optimized images, for example).
Public Function GetNullMetadataSettings() As String
    Dim cParams As pdParamXML
    Set cParams = New pdParamXML
    cParams.AddParam "MetadataExportAllowed", False
    GetNullMetadataSettings = cParams.GetParamString
End Function

'Update the UI against a previously saved set of metadata settings in XML format
Public Sub SetMetadataSettings(ByRef srcXML As String, Optional ByVal srcIsPresetManager As Boolean = False)

    Dim cParams As pdParamXML
    Set cParams = New pdParamXML
    cParams.SetParamString srcXML
    
    If cParams.GetBool("MetadataExportAllowed", True) Then chkMetadata.Value = vbChecked Else chkMetadata.Value = vbUnchecked
    If cParams.GetBool("MetadataAnonymize", False) Then chkAnonymize.Value = vbChecked Else chkAnonymize.Value = vbUnchecked
    If cParams.GetBool("MetadataEmbedThumbnail", False) Then chkThumbnail.Value = vbChecked Else chkThumbnail.Value = vbUnchecked
    
End Sub

Public Sub Reset()
    chkMetadata.Value = vbChecked
    chkAnonymize.Value = vbUnchecked
    chkThumbnail.Value = vbUnchecked
End Sub

Public Sub SetParentImage(ByRef srcImage As pdImage, ByVal destinationFormat As PHOTODEMON_IMAGE_FORMAT)
    Set m_ImageCopy = srcImage
    m_DstFormat = destinationFormat
    EvaluatePresenceOfMetadata
    UpdateMainComponentVisibility
    UpdateFormatComponentVisibility
End Sub

'If the parent image has metadata, we provide a bold notification to the user.  (We also retrieve the metadata presets,
' if any, from the parent image.)
Private Sub EvaluatePresenceOfMetadata()
    If (Not (m_ImageCopy Is Nothing)) Then
        If m_ImageCopy.imgMetadata.HasMetadata Then
            lblTitle.Caption = g_Language.TranslateMessage("This image contains metadata.")
            lblTitle.FontBold = True
            hplReviewMetadata.Caption = g_Language.TranslateMessage("click to review this image's metadata")
        Else
            lblTitle.Caption = g_Language.TranslateMessage("This image does not contain metadata.")
            lblTitle.FontBold = False
            hplReviewMetadata.Caption = g_Language.TranslateMessage("click to add metadata to this image")
        End If
    End If
End Sub

'Show/hide the bottom label and hyperlink, contingent on the presence of metadata in the target image
Private Sub UpdateMainComponentVisibility()

    Dim imgHasMetadata As Boolean: imgHasMetadata = False
    If Not (m_ImageCopy Is Nothing) Then
        lblTitle.Visible = True
        hplReviewMetadata.Visible = True
    Else
        lblTitle.Visible = False
        hplReviewMetadata.Visible = False
    End If

End Sub

'Show/hide any format-specific parameters.  Make sure m_DstFormat is set before calling this, obviously!
Private Sub UpdateFormatComponentVisibility()
    
    Select Case m_DstFormat
        
        Case PDIF_JPEG
            lblInfo(1).Caption = g_Language.TranslateMessage("JPEG-specific settings")
            lblInfo(1).Visible = True
            chkThumbnail.Visible = True
            
        Case Else
            lblInfo(1).Visible = False
            chkThumbnail.Visible = False
    
    End Select
    
End Sub

Private Function IsThumbnailSupported() As Boolean
    
    Select Case m_DstFormat
        
        Case PDIF_JPEG
            IsThumbnailSupported = True
            
        Case Else
            IsThumbnailSupported = False
    
    End Select
    
End Function

'By design, PD prefers to not use design-time tooltips.  Apply tooltips at run-time, using this function.
' (IMPORTANT NOTE: translations are handled automatically.  Always pass the original English text!)
Public Sub AssignTooltip(ByVal newTooltip As String, Optional ByVal newTooltipTitle As String, Optional ByVal newTooltipIcon As TT_ICON_TYPE = TTI_NONE)
    ucSupport.AssignTooltip UserControl.ContainerHwnd, newTooltip, newTooltipTitle, newTooltipIcon
End Sub

