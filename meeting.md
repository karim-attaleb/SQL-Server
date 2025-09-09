PAR datagroup=MSS
PAR pkgname=DB_MSS0_DEMO
PAR pkgversion=0.0.1
PAR pkgtype=LOLA
PAR database=DB_MSS0_DEMO
PAR pkgdesc=SQL Database Package DEMO
PAR pkgversiondesc=SQL Database Package DEMO
PAR subsystem=C48
PAR ou=0005

PAR IF pillar=DEV THEN servername=S2S005G2\POD07_DEV
PAR IF pillar=DEV THEN instance=POD07_DEV
PAR IF pillar=DEV THEN userdomain=TDA001 
PAR IF pillar=DEV THEN DBSIZE=200MB 
PAR IF pillar=DEV THEN DBGROWTH=100MB 
PAR IF pillar=DEV THEN LOGSIZE=100MB 
PAR IF pillar=DEV THEN LOGGROWTH=100MB 
PAR IF pillar=DEV THEN ou=1005 

PAR IF pillar=ACC THEN servername=S1S005R2\POD07_ACC
PAR IF pillar=ACC THEN instance=POD07_ACC
PAR IF pillar=ACC THEN userdomain=TDA001 
PAR IF pillar=ACC THEN DBSIZE=200MB 
PAR IF pillar=ACC THEN DBGROWTH=100MB 
PAR IF pillar=ACC THEN LOGSIZE=100MB 
PAR IF pillar=ACC THEN LOGGROWTH=100MB

PAR IF pillar=PRO THEN servername=S0AB05X6\POD07_PRO
PAR IF pillar=PRO THEN instance=POD07_PRO
PAR IF pillar=PRO THEN userdomain=GLOW001 
PAR IF pillar=PRO THEN DBSIZE=250MB 
PAR IF pillar=PRO THEN DBGROWTH=100MB 
PAR IF pillar=PRO THEN LOGSIZE=100MB  
PAR IF pillar=PRO THEN LOGGROWTH=100MB 

PAR datadrive=G
PAR logdrive=E

PAR IF host=S288617J THEN servername=S288617J\SDD02_TST
PAR IF host=S288617J THEN instance=SDD02_TST
PAR IF host=S288617J THEN userdomain=TDA001 
PAR IF host=S288617J THEN ou=1005 
PAR IF host=S288617J THEN DBSIZE=50MB 
PAR IF host=S288617J THEN DBGROWTH=10MB 
PAR IF host=S288617J THEN LOGSIZE=50MB 
PAR IF host=S288617J THEN LOGGROWTH=10MB 

SQL
-- body

USE [master]
GO

:setvar datagroup "##datagroup##"
:setvar instance "##instance##"
:setvar datadrive "##datadrive##"
:setvar logdrive "##logdrive##"
:setvar userdomain "##userdomain##"
:setvar ou "##ou##"
:setvar DBSIZE "##DBSIZE##"
:setvar DBGROWTH "##DBGROWTH##"
:setvar LOGSIZE "##LOGSIZE##"
:setvar LOGGROWTH "##LOGGROWTH##"

:setvar userdev "1"
:setvar userprw "1"
:setvar userpro "1"
:setvar userfnc "1"
:setvar userap1 "0"

:setvar database "DB_MSS0_DEMO"
:setvar subapp "_01"

IF db_id('$(database)') IS NOT NULL
    Print 'Database $(database) already exists.'
ELSE
   BEGIN 
   CREATE DATABASE [$(database)] ON  PRIMARY 
  ( NAME = N'$(database) ', FILENAME = N'$(datadrive):\$(instance)\data\$(database).mdf' , SIZE = $(DBSIZE) , MAXSIZE = UNLIMITED, FILEGROWTH = $(DBGROWTH))
   LOG ON 
  ( NAME = N'$(database)_log', FILENAME = N'$(logdrive):\$(instance)\log\$(database)_log.ldf' , SIZE = $(LOGSIZE)  , MAXSIZE = UNLIMITED , FILEGROWTH = $(LOGGROWTH) )
   END
GO

IF ($(userdev) = '1' and $(ou) = '1005')
BEGIN  
IF NOT EXISTS(SELECT name FROM sys.server_principals WHERE name = '$(userdomain)\$(ou)_GS_$(datagroup)0$(subapp)_DEV_RW') 
   BEGIN  
   CREATE LOGIN [$(userdomain)\$(ou)_GS_$(datagroup)0$(subapp)_DEV_RW] FROM WINDOWS WITH DEFAULT_DATABASE=[master]
   END
END
GO

IF $(userap1) = '1'
BEGIN  
IF NOT EXISTS(SELECT name FROM sys.server_principals WHERE name = '$(userdomain)\$(ou)_GS_$(datagroup)0$(subapp)_APP_R1') 
   BEGIN  
   CREATE LOGIN [$(userdomain)\$(ou)_GS_$(datagroup)0$(subapp)_APP_R1] FROM WINDOWS WITH DEFAULT_DATABASE=[master]
   END
END
GO

IF $(userfnc) = '1'
BEGIN  
IF NOT EXISTS(SELECT name FROM sys.server_principals WHERE name = '$(userdomain)\$(ou)_GS_$(datagroup)0$(subapp)_FNC_RW') 
   BEGIN  
   CREATE LOGIN [$(userdomain)\$(ou)_GS_$(datagroup)0$(subapp)_FNC_RW] FROM WINDOWS WITH DEFAULT_DATABASE=[master]
   END
END
GO

IF $(userprw) = '1'
BEGIN  
IF NOT EXISTS(SELECT name FROM sys.server_principals WHERE name = '$(userdomain)\$(ou)_GS_$(datagroup)0$(subapp)_PRS_RW') 
   BEGIN  
   CREATE LOGIN [$(userdomain)\$(ou)_GS_$(datagroup)0$(subapp)_PRS_RW] FROM WINDOWS WITH DEFAULT_DATABASE=[master]
   END
END
GO 
  
IF $(userpro) = '1'
BEGIN  
IF NOT EXISTS(SELECT name FROM sys.server_principals WHERE name = '$(userdomain)\$(ou)_GS_$(datagroup)0$(subapp)_PRS_RO') 
   BEGIN  
   CREATE LOGIN [$(userdomain)\$(ou)_GS_$(datagroup)0$(subapp)_PRS_RO] FROM WINDOWS WITH DEFAULT_DATABASE=[master]
   END
END
GO 

-- execute DatabaseIntegrityCheck proc ola.hallengren
-- https://ola.hallengren.com/sql-server-integrity-check.html

USE [master]
GO
IF OBJECT_ID('DatabaseIntegrityCheck', 'P') IS NOT NULL
EXECUTE [dbo].[DatabaseIntegrityCheck] @Databases = '$(database)', @LogToTable = 'Y'
GO

-- execute sql-server-index-and-statistics-maintenance proc ola.hallengren
-- https://ola.hallengren.com/sql-server-index-and-statistics-maintenance.html

IF OBJECT_ID('IndexOptimize', 'P') IS NOT NULL
EXECUTE [dbo].[IndexOptimize] @Databases = '$(database)', @LogToTable = 'Y'
GO

-- create Query Store on SQL2016 or higher
declare @version char(12);
set     @version =  convert(char(12),serverproperty('productversion'));
if not (select substring(@version, 1, 2)) in ('10','11','12')      -- v2008=10 v2012=11 v2014=12 v2016=13
   BEGIN
   EXEC('
   ALTER DATABASE [$(database)] SET QUERY_STORE = ON
   ALTER DATABASE [$(database)] SET QUERY_STORE (OPERATION_MODE = READ_WRITE, CLEANUP_POLICY = (STALE_QUERY_THRESHOLD_DAYS = 31), 
             INTERVAL_LENGTH_MINUTES = 15, QUERY_CAPTURE_MODE = AUTO, MAX_STORAGE_SIZE_MB = 100,
             DATA_FLUSH_INTERVAL_SECONDS = 900,SIZE_BASED_CLEANUP_MODE = AUTO,MAX_PLANS_PER_QUERY = 100)
   PRINT ''Query Store created on $(database)''
   ')
   END

  
USE [$(database)]
GO
IF NOT EXISTS(SELECT '1'  FROM sys.databases WHERE name = '$(database)' and suser_sname(owner_sid) = 'sa' ) 
    BEGIN
    EXEC sp_changedbowner 'sa'
    Print 'Database $(database) owner changed to sa'
    END
GO





-- PRINT INFO
exec sp_helpfile;
GO



-- add executor role
IF NOT EXISTS (SELECT name FROM sys.database_principals WHERE name = 'db_executor')
    BEGIN     
    CREATE ROLE [db_executor] AUTHORIZATION [dbo]
    GRANT EXECUTE TO [db_executor]
    END
GO

IF ($(userdev) = '1' and $(ou) = '1005')
BEGIN  
                              IF NOT EXISTS (SELECT name FROM sys.database_principals WHERE name = '$(userdomain)\$(ou)_GS_$(datagroup)0$(subapp)_DEV_RW')
                                             BEGIN  
                                             CREATE USER [$(userdomain)\$(ou)_GS_$(datagroup)0$(subapp)_DEV_RW] FOR LOGIN [$(userdomain)\$(ou)_GS_$(datagroup)0$(subapp)_DEV_RW] WITH DEFAULT_SCHEMA=[dbo]
                                             EXEC sp_addrolemember N'db_owner', N'$(userdomain)\$(ou)_GS_$(datagroup)0$(subapp)_DEV_RW'
                   END
END
GO

IF $(userap1) = '1'
BEGIN  
                              IF NOT EXISTS (SELECT name FROM sys.database_principals WHERE name = '$(userdomain)\$(ou)_GS_$(datagroup)0$(subapp)_APP_R1')
                                             BEGIN  
                                             CREATE USER [$(userdomain)\$(ou)_GS_$(datagroup)0$(subapp)_APP_R1] FOR LOGIN [$(userdomain)\$(ou)_GS_$(datagroup)0$(subapp)_APP_R1] WITH DEFAULT_SCHEMA=[dbo]
                                                              EXEC sp_addrolemember N'db_datareader', N'$(userdomain)\$(ou)_GS_$(datagroup)0$(subapp)_APP_R1'
                                                             EXEC sp_addrolemember N'db_datawriter', N'$(userdomain)\$(ou)_GS_$(datagroup)0$(subapp)_APP_R1'
                       EXEC sp_addrolemember N'db_executor', N'$(userdomain)\$(ou)_GS_$(datagroup)0$(subapp)_APP_R1'
                     END
END
GO

IF $(userfnc) = '1'
BEGIN  
IF NOT EXISTS (SELECT name FROM sys.database_principals WHERE name = '$(userdomain)\$(ou)_GS_$(datagroup)0$(subapp)_FNC_RW')
   BEGIN     
   CREATE USER [$(userdomain)\$(ou)_GS_$(datagroup)0$(subapp)_FNC_RW] FOR LOGIN [$(userdomain)\$(ou)_GS_$(datagroup)0$(subapp)_FNC_RW] WITH DEFAULT_SCHEMA=[dbo]
               EXEC sp_addrolemember N'db_datareader', N'$(userdomain)\$(ou)_GS_$(datagroup)0$(subapp)_FNC_RW'
               EXEC sp_addrolemember N'db_datawriter', N'$(userdomain)\$(ou)_GS_$(datagroup)0$(subapp)_FNC_RW'
               EXEC sp_addrolemember N'db_executor', N'$(userdomain)\$(ou)_GS_$(datagroup)0$(subapp)_FNC_RW'
   END
END
GO
IF $(userpro) = '1'
BEGIN     
IF NOT EXISTS (SELECT name FROM sys.database_principals WHERE name = '$(userdomain)\$(ou)_GS_$(datagroup)0$(subapp)_PRS_RO')
   BEGIN     
   CREATE USER [$(userdomain)\$(ou)_GS_$(datagroup)0$(subapp)_PRS_RO] FOR LOGIN [$(userdomain)\$(ou)_GS_$(datagroup)0$(subapp)_PRS_RO] WITH DEFAULT_SCHEMA=[dbo]
   EXEC sp_addrolemember N'db_datareader', N'$(userdomain)\$(ou)_GS_$(datagroup)0$(subapp)_PRS_RO'
               EXEC sp_addrolemember N'db_denydatawriter', N'$(userdomain)\$(ou)_GS_$(datagroup)0$(subapp)_PRS_RO'
   END
END
GO
IF $(userprw) = '1'
BEGIN  
IF NOT EXISTS (SELECT name FROM sys.database_principals WHERE name = '$(userdomain)\$(ou)_GS_$(datagroup)0$(subapp)_PRS_RW')
   BEGIN     
   CREATE USER [$(userdomain)\$(ou)_GS_$(datagroup)0$(subapp)_PRS_RW] FOR LOGIN [$(userdomain)\$(ou)_GS_$(datagroup)0$(subapp)_PRS_RW] WITH DEFAULT_SCHEMA=[dbo]
   EXEC sp_addrolemember N'db_datareader', N'$(userdomain)\$(ou)_GS_$(datagroup)0$(subapp)_PRS_RW'
               EXEC sp_addrolemember N'db_datawriter', N'$(userdomain)\$(ou)_GS_$(datagroup)0$(subapp)_PRS_RW'
               EXEC sp_addrolemember N'db_executor', N'$(userdomain)\$(ou)_GS_$(datagroup)0$(subapp)_PRS_RW'
   END
END
GO
