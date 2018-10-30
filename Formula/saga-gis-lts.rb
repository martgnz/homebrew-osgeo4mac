class SagaGisLts < Formula
  desc "System for Automated Geoscientific Analyses - Long Term Support"
  homepage "http://saga-gis.org"
  url "https://git.code.sf.net/p/saga-gis/code.git",
      :branch => "release-2-3-lts",
      :revision => "b6f474f8af4af7f0ff82548cc6f88c53547d91f5"
  version "2.3.2"

  revision 1

  head "https://git.code.sf.net/p/saga-gis/code.git", :branch => "release-2-3-lts"

  bottle do
    root_url "https://dl.bintray.com/homebrew-osgeo/osgeo-bottles"
    sha256 "a3bacd3cf88cd5b314fef185de5cb50273d2c1faf2cb6c287ee3bfc7d6a07f9f" => :mojave
    sha256 "a3bacd3cf88cd5b314fef185de5cb50273d2c1faf2cb6c287ee3bfc7d6a07f9f" => :high_sierra
    sha256 "a3bacd3cf88cd5b314fef185de5cb50273d2c1faf2cb6c287ee3bfc7d6a07f9f" => :sierra
  end

  # - saga_api, CSG_Table::Del_Records(): bug fix, check record count correctly
  # - fix clang
  # - io_gdal, org_driver: do not use methods marked as deprecated in GDAL 2.0
  #   https://sourceforge.net/p/saga-gis/bugs/245/
  patch :DATA

  keg_only "LTS version is specifically for working with QGIS"

  option "with-app", "Build SAGA.app Package"

  depends_on "automake" => :build
  depends_on "autoconf" => :build
  depends_on "libtool" => :build
  depends_on "pkg-config" => :build
  depends_on "gdal2"
  depends_on "proj"
  depends_on "wxmac"
  depends_on "geos"
  depends_on "gdal2"
  depends_on "laszip"
  depends_on "jasper"
  depends_on "fftw"
  depends_on "libtiff"
  depends_on "swig"
  depends_on "xz" # lzma
  depends_on "giflib"
  depends_on "unixodbc" => :recommended
  depends_on "libharu" => :recommended
  depends_on "qhull" => :recommended # instead of looking for triangle
  # Vigra support builds, but dylib in saga shows 'failed' when loaded
  # Also, using --with-python will trigger vigra to be built with it, which
  # triggers a source (re)build of boost --with-python
  depends_on "brewsci/science/vigra" => :optional
  depends_on "postgresql" => :optional
  depends_on "python@2" => :optional
  depends_on "opencv@2" => :optional
  # depends_on "opencv" => :optional
  depends_on "liblas" => :optional
  depends_on "poppler" => :optional
  depends_on "osgeo/osgeo4mac/hdf4" => :optional
  depends_on "hdf5" => :optional
  depends_on "netcdf" => :optional
  depends_on "sqlite" => :optional

  resource "app_icon" do
    url "https://osgeo4mac.s3.amazonaws.com/src/saga_gui.icns"
    sha256 "288e589d31158b8ffb9ef76fdaa8e62dd894cf4ca76feabbae24a8e7015e321f"
  end

  def install
    # SKIP liblas support until SAGA supports > 1.8.1, which should support GDAL 2;
    #      otherwise, SAGA binaries may lead to multiple GDAL versions being loaded
    # See: https://github.com/libLAS/libLAS/issues/106
    ENV.cxx11

    cxxflags= system "wx-config", "--version=3.0", "--cxxflags"
    libs = system "wx-config", "--version=3.0", "--libs"

    ENV.append "CPPFLAGS", "-I#{Formula["proj"].opt_include}"
    # Disable narrowing warnings when compiling in C++11 mode.
    ENV.append "CXXFLAGS", "-Wno-c++11-narrowing -std=c++11 #{cxxflags}"
    ENV.append "LDFLAGS", "-L#{Formula["proj"].opt_lib}/libproj.dylib #{libs}"

    cd "saga-gis"

    # fix homebrew-specific header location for qhull
    inreplace "src/modules/grid/grid_gridding/nn/delaunay.c", "qhull/", "libqhull/" if build.with? "qhull"

    # libfire and triangle are for non-commercial use only, skip them
    args = %W[
      --prefix=#{prefix}
      --disable-dependency-tracking
      --disable-openmp
      --disable-libfire
      --disable-triangle
      --enable-shared
      --enable-debug
    ]

    # --disable-gui

    args << "--disable-odbc" if build.without? "unixodbc"
    args << "--disable-triangle" if build.with? "qhull"
    args << "--with-postgresql=#{Formula["postgresql"].opt_bin}/pg_config" if build.with? "postgresql"
    args << "--with-python" if build.with? "python"

    system "autoreconf", "-i"
    system "./configure", *args
    system "make", "install"

    if build.with? "app"
      # Based on original script by Phil Hess
      # http://web.fastermac.net/~MacPgmr/

      buildpath.install resource("app_icon")
      mkdir_p "#{buildpath}/SAGA.app/Contents/MacOS"
      mkdir_p "#{buildpath}/SAGA.app/Contents/Resources"

      (buildpath/"SAGA.app/Contents/PkgInfo").write "APPLSAGA"
      cp "#{buildpath}/saga_gui.icns", "#{buildpath}/SAGA.app/Contents/Resources/"
      ln_s "#{bin}/saga_gui", "#{buildpath}/SAGA.app/Contents/MacOS/saga_gui"

      config = <<~EOS
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
          <key>CFBundleDevelopmentRegion</key>
          <string>English</string>
          <key>CFBundleExecutable</key>
          <string>saga_gui</string>
          <key>CFBundleIconFile</key>
          <string>saga_gui.icns</string>
          <key>CFBundleInfoDictionaryVersion</key>
          <string>6.0</string>
          <key>CFBundleName</key>
          <string>SAGA</string>
          <key>CFBundlePackageType</key>
          <string>APPL</string>
          <key>CFBundleSignature</key>
          <string>SAGA</string>
          <key>CFBundleVersion</key>
          <string>1.0</string>
          <key>CSResourcesFileMapped</key>
          <true/>
          <key>NSHighResolutionCapable</key>
          <string>True</string>
        </dict>
        </plist>
      EOS

      (buildpath/"SAGA.app/Contents/Info.plist").write config
      prefix.install "SAGA.app"

    end
  end

  def caveats
    if build.with? "app"
      <<~EOS
      SAGA.app was installed in:
        #{prefix}

      Note that the SAGA GUI does not work very well yet.
      It has problems with creating a preferences file in the correct location and sometimes won't shut down (use Activity Monitor to force quit if necessary).
      EOS
    end
  end

  test do
    output = `#{bin}/saga_cmd --help`
    assert_match /The SAGA command line interpreter/, output
  end
end

__END__
--- a/saga-gis/src/saga_core/saga_api/table.cpp
+++ b/saga-gis/src/saga_core/saga_api/table.cpp
@@ -901,7 +901,7 @@
 //---------------------------------------------------------
 bool CSG_Table::Del_Records(void)
 {
-	if( m_Records > 0 )
+	if( m_nRecords > 0 )
 	{
 		_Index_Destroy();


--- a/saga-gis/src/modules/imagery/imagery_maxent/me.cpp
+++ b/saga-gis/src/modules/imagery/imagery_maxent/me.cpp
@@ -21,7 +21,7 @@
 #ifdef _SAGA_MSW
 #define isinf(x) (!_finite(x))
 #else
-#define isinf(x) (!finite(x))
+#define isinf(x) (!isfinite(x))
 #endif

 /** The input array contains a set of log probabilities lp1, lp2, lp3


--- a/saga-gis/src/modules/io/io_gdal/ogr_driver.cpp
+++ b/saga-gis/src/modules/io/io_gdal/ogr_driver.cpp
@@ -531,12 +531,11 @@
 //---------------------------------------------------------
 int CSG_OGR_DataSet::Get_Count(void)	const
 {
-	if( m_pDataSet )
-	{
-		return OGR_DS_GetLayerCount( m_pDataSet );
-	}
-
-	return( 0 );
+#ifdef USE_GDAL_V2
+	return( m_pDataSet ? GDALDatasetGetLayerCount(m_pDataSet) : 0 );
+#else
+ 	return( m_pDataSet ? OGR_DS_GetLayerCount(m_pDataSet) : 0 );
+#endif
 }

 //---------------------------------------------------------
@@ -544,7 +543,11 @@
 {
 	if( m_pDataSet && iLayer >= 0 && iLayer < Get_Count() )
 	{
-		return OGR_DS_GetLayer( m_pDataSet, iLayer);
+#ifdef USE_GDAL_V2
+	return( GDALDatasetGetLayer(m_pDataSet, iLayer) );
+#else
+	return( OGR_DS_GetLayer(m_pDataSet, iLayer) );
+#endif
 	}

 	return( NULL );
@@ -630,44 +633,43 @@
 	}

 	//-----------------------------------------------------
-	OGRFeatureDefnH pDef = OGR_L_GetLayerDefn( pLayer );
-	CSG_Shapes		*pShapes	= SG_Create_Shapes(Get_Type(iLayer), CSG_String(OGR_Fld_GetNameRef(pDef)), NULL, Get_Coordinate_Type(iLayer));
+	OGRFeatureDefnH	pDefn	= OGR_L_GetLayerDefn(pLayer);
+	CSG_Shapes		*pShapes	= SG_Create_Shapes(Get_Type(iLayer), CSG_String(OGR_L_GetName(pLayer)), NULL, Get_Coordinate_Type(iLayer));

 	pShapes->Get_Projection()	= Get_Projection(iLayer);

 	//-----------------------------------------------------
-	int		iField;
-
-	for(iField=0; iField< OGR_FD_GetFieldCount(pDef); iField++)
-	{
-		OGRFieldDefnH pDefField	= OGR_FD_GetFieldDefn( pDef, iField);
-
-		pShapes->Add_Field( OGR_Fld_GetNameRef( pDefField ), CSG_OGR_Drivers::Get_Data_Type( OGR_Fld_GetType( pDefField ) ) );
-	}
+	{
+		for(int iField=0; iField<OGR_FD_GetFieldCount(pDefn); iField++)
+		{
+			OGRFieldDefnH	pDefnField	= OGR_FD_GetFieldDefn(pDefn, iField);
+
+			pShapes->Add_Field(OGR_Fld_GetNameRef(pDefnField), CSG_OGR_Drivers::Get_Data_Type(OGR_Fld_GetType(pDefnField)));
+		}
+	}
+

 	//-----------------------------------------------------
 	OGRFeatureH pFeature;
-
-	OGR_L_ResetReading( pLayer );
-
-	while( (pFeature = OGR_L_GetNextFeature( pLayer ) ) != NULL && SG_UI_Process_Get_Okay(false) )
-	{
-		OGRGeometryH pGeometry = OGR_F_GetGeometryRef( pFeature );
+	OGR_L_ResetReading(pLayer);
+
+	while( (pFeature = OGR_L_GetNextFeature(pLayer)) != NULL && SG_UI_Process_Get_Okay(false) )
+	{
+		OGRGeometryH	pGeometry	= OGR_F_GetGeometryRef(pFeature);

 		if( pGeometry != NULL )
 		{
 			CSG_Shape	*pShape	= pShapes->Add_Shape();

-			for(iField=0; iField<OGR_FD_GetFieldCount(pDef); iField++)
+			for(int iField=0; iField<pShapes->Get_Field_Count(); iField++)
 			{
-				OGRFieldDefnH pDefField	= OGR_FD_GetFieldDefn(pDef, iField);
-
-				switch( OGR_Fld_GetType( pDefField ) )
+				switch( pShapes->Get_Field_Type(iField) )
 				{
-				default:			pShape->Set_Value(iField, OGR_F_GetFieldAsString( pFeature, iField));	break;
-				case OFTString:		pShape->Set_Value(iField, OGR_F_GetFieldAsString( pFeature, iField));	break;
-				case OFTInteger:	pShape->Set_Value(iField, OGR_F_GetFieldAsInteger( pFeature, iField));	break;
-				case OFTReal:		pShape->Set_Value(iField, OGR_F_GetFieldAsDouble( pFeature, iField));	break;
+				default                : pShape->Set_Value(iField, OGR_F_GetFieldAsString (pFeature, iField)); break;
+				case SG_DATATYPE_String: pShape->Set_Value(iField, OGR_F_GetFieldAsString (pFeature, iField)); break;
+				case SG_DATATYPE_Int   : pShape->Set_Value(iField, OGR_F_GetFieldAsInteger(pFeature, iField)); break;
+				case SG_DATATYPE_Float : pShape->Set_Value(iField, OGR_F_GetFieldAsDouble (pFeature, iField)); break;
+				case SG_DATATYPE_Double: pShape->Set_Value(iField, OGR_F_GetFieldAsDouble (pFeature, iField)); break;
 				}
 			}
