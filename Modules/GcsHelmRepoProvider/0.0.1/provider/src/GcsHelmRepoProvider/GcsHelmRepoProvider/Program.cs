//https://cloud.google.com/dotnet/docs/reference/Google.Cloud.Storage.V1/latest/Google.Cloud.Storage.V1
using System;
using System.IO;
using System.Diagnostics;
using System.Collections;
using System.Collections.ObjectModel;
using System.Management.Automation;
using System.Management.Automation.Provider;
using System.Text;
using System.Text.RegularExpressions;
using System.ComponentModel;
using System.Globalization;
using Google.Cloud.Storage.V1;
using Google.Apis.Storage.v1.Data;


namespace Custom.Providers
{
    #region GoogleCloudStorageProvider

    /// <summary>
    /// This example implements the content methods.
    /// </summary>
    [CmdletProvider("GoogleCloudStorage", 
        ProviderCapabilities.ShouldProcess | 
        ProviderCapabilities.Transactions | 
        ProviderCapabilities.Credentials | 
        ProviderCapabilities.Exclude | 
        ProviderCapabilities.Include | 
        ProviderCapabilities.ExpandWildcards | 
        ProviderCapabilities.Filter)
    ]
    public class GoogleCloudStorageProvider : NavigationCmdletProvider//, IContentCmdletProvider
    {
        private string pathSeparator = "/";
        private static string pattern = @"^[-a-zA-Z0-9_!][-a-zA-Z0-9_!.]+$";


       #region Drive Manipulation

        /// <summary>
        /// Create a new drive.  Create a connection to the database file and set
        /// the Connection property in the PSDriveInfo.
        /// </summary>
        /// <param name="drive">
        /// Information describing the drive to add.
        /// <returns>The added drive.</returns>
        protected override PSDriveInfo NewDrive(PSDriveInfo drive)
        {
            // check if drive object is null
            if (drive == null)
            {
                WriteError(new ErrorRecord(
                    new ArgumentNullException("drive"),
                    "NullDrive",
                    ErrorCategory.InvalidArgument,
                    null)
                );

                return null;
            }

            // check if drive root is not null or empty
            // and if its an existing file
            if (String.IsNullOrEmpty(drive.Root) || (File.Exists(drive.Root) == false))
            {
                WriteError(new ErrorRecord(
                    new ArgumentException("drive.Root"),
                    "NoRoot",
                    ErrorCategory.InvalidArgument,
                    drive)
                );

                return null;
            }

            // create a new drive and create an ODBC connection to the new drive
            GoogleCloudStoragePSDriveInfo GoogleCloudStoragePSDriveInfo = new GoogleCloudStoragePSDriveInfo(drive);
            
            var clientBuilder = new StorageClientBuilder();
            clientBuilder.BaseUri = drive.DisplayRoot;
            clientBuilder.ApplicationName = "GcsHelmRepoProvider";
            var client = clientBuilder.Build();

            GoogleCloudStoragePSDriveInfo.GcsClient = client;
            GoogleCloudStoragePSDriveInfo.BucketUrl = drive.DisplayRoot;
            
            return GoogleCloudStoragePSDriveInfo;
        } // NewDrive

        /// <summary>
        /// Removes a drive from the provider.
        /// </summary>
        /// <param name="drive">The drive to remove.</param>
        /// <returns>The drive removed.</returns>
        protected override PSDriveInfo RemoveDrive(PSDriveInfo drive)
        {
            // check if drive object is null
            if (drive == null)
            {
                WriteError(new ErrorRecord(
                    new ArgumentNullException("drive"),
                    "NullDrive",
                    ErrorCategory.InvalidArgument,
                    drive)
                );

                return null;
            }

            // close ODBC connection to the drive
            GoogleCloudStoragePSDriveInfo GoogleCloudStoragePSDriveInfo = drive as GoogleCloudStoragePSDriveInfo;

            if (GoogleCloudStoragePSDriveInfo == null)
            {
                return null;
            }
            GoogleCloudStoragePSDriveInfo.GcsClient.Dispose();

            return GoogleCloudStoragePSDriveInfo;
        } // RemoveDrive

        #endregion Drive Manipulation

       #region Item Methods

        /// <summary>
        /// Retrieves an item using the specified path.
        /// </summary>
        /// <param name="path">The path to the item to return.</param>
        protected override Object GetItem(string path)
        {
            // TO-DO wtf is this
            // check if the path represented is a drive
            if (PathIsDrive(path))
            {
                WriteItemObject(this.PSDriveInfo, path, true);
                return;
            }

            var client = StorageClient.Create();

            var gcsPath = GetGcsPath(path);
            
            return client.GetObject(gcsPath.BucketName, gcsPath.ObjectPath)
        }

        /// <summary>
        /// Set the content of a row of data specified by the supplied path
        /// parameter.
        /// </summary>
        /// <param name="path">Specifies the path to the row whose columns
        /// will be updated.</param>
        /// <param name="values">Comma separated string of values</param>
        protected override void SetItem(string path, object values)
        {
            var gcsPath = GetGcsPath(path);

            if (type != PathType.Row)
            {
                WriteError(new ErrorRecord(new NotSupportedException(
                      "SetNotSupported"), "",
                   ErrorCategory.InvalidOperation, path));

                return;
            }

            string[] colValues = (values as string).Split(',');

            for (int i = 0; i < colValues.Length; i++)
            {
                row[i] = colValues[i];
            }

            // Update the table
            if (ShouldProcess(path, "SetItem"))
            {
                da.Update(ds, objectName);
            }

        } // SetItem

        /// <summary>
        /// Test to see if the specified item exists.
        /// </summary>
        /// <param name="path">The path to the item to verify.</param>
        /// <returns>True if the item is found.</returns>
        protected override bool ItemExists(string path)
        {
            // check if the path represented is a drive
            if (PathIsDrive(path))
            {
                return true;
            }

            var gcsPath = GetGcsPath(path);

            var itemInGcs = GetItem(objectName);
            if (itemInGcs == null)
            {
                return false;
            }
            return true;
        } // ItemExists

        /// <summary>
        /// Test to see if the specified path is syntactically valid.
        /// </summary>
        /// <param name="path">The path to validate.</param>
        /// <returns>True if the specified path is valid.</returns>
        protected override bool IsValidPath(string path)
        {
            // check if the path is null or empty
            if (String.IsNullOrEmpty(path))
            {
                return false;
            }

            // convert all separators in the path to a uniform one
            path = NormalizePath(path);

            // split the path into individual chunks
            string[] pathChunks = path.Split(pathSeparator.ToCharArray());

            if (pathChunks.Length < 1)
            {
                return false;
            }

            foreach (string pathChunk in pathChunks)
            {
                if (pathChunk.Length == 0)
                {
                    return false;
                }
            }
            return true;
        } // IsValidPath

        #endregion Item Overloads

       #region Container Overloads

        /// <summary>
        /// Return either the tables in the database or the datarows
        /// </summary>
        /// <param name="path">The path to the parent</param>
        /// <param name="recurse">True to return all child items recursively.
        /// </param>
        protected override void GetChildItems(string path, bool recurse)
        {
            var drive = this.PSDriveInfo as GoogleCloudStoragePSDriveInfo;
            // If path represented is a drive then the children in the path are 
            // tables. Hence all tables in the drive represented will have to be
            // returned
            if (PathIsDrive(path))
            {
                string[] projectBuckets = drive.GcsClient.ListBuckets(drive.ProjectId)
                foreach (var bucket in projectBuckets)
                {
                    WriteItemObject(bucket, path, true);

                    // if the specified item exists and recurse has been set then 
                    // all child items within it have to be obtained as well
                    if (ItemExists(path) && recurse)
                    {
                        GetChildItems(path + pathSeparator + bucket.Name, recurse);
                    }
                } // foreach (DatabaseTableInfo...
            } // if (PathIsDrive...
            if (PathIsBucket(path))
            {
                objectPrefix = GetObjectPrefix(path)
                string[] bucketObjects = drive.GcsClient.ListObjects(bucket, null, null)
            }
            else
            {
                // Get the table name, row number and type of path from the
                // path specified
                string objectName;
                int rowNumber;

                PathType type = GetNamesFromPath(path, out objectName, out rowNumber);

                if (type == PathType.Table)
                {
                    // Obtain all the rows within the table
                    foreach (DatabaseRowInfo row in GetRows(objectName))
                    {
                        WriteItemObject(row, path + pathSeparator + row.RowNumber,
                                false);
                    } // foreach (DatabaseRowInfo...
                }
                else if (type == PathType.Row)
                {
                    // In this case the user has directly specified a row, hence
                    // just give that particular row
                    DatabaseRowInfo row = GetRow(objectName, rowNumber);
                    WriteItemObject(row, path + pathSeparator + row.RowNumber,
                                false);
                }
                else
                {
                    // In this case, the path specified is not valid
                    ThrowTerminatingInvalidPathException(path);
                }
            } // else
        } // GetChildItems

        /// <summary>
        /// Return the names of all child items.
        /// </summary>
        /// <param name="path">The root path.</param>
        /// <param name="returnContainers">Not used.</param>
        protected override void GetChildNames(string path,
                                      ReturnContainers returnContainers)
        {
            // If the path represented is a drive, then the child items are
            // tables. get the names of all the tables in the drive.
            if (PathIsDrive(path))
            {
                foreach (DatabaseTableInfo table in GetTables())
                {
                    WriteItemObject(table.Name, path, true);
                } // foreach (DatabaseTableInfo...
            } // if (PathIsDrive...
            else
            {
                // Get type, table name and row number from path specified
                string objectName;
                int rowNumber;

                PathType type = GetNamesFromPath(path, out objectName, out rowNumber);

                if (type == PathType.Table)
                {
                    // Get all the rows in the table and then write out the 
                    // row numbers.
                    foreach (DatabaseRowInfo row in GetRows(objectName))
                    {
                        WriteItemObject(row.RowNumber, path, false);
                    } // foreach (DatabaseRowInfo...
                }
                else if (type == PathType.Row)
                {
                    // In this case the user has directly specified a row, hence
                    // just give that particular row
                    DatabaseRowInfo row = GetRow(objectName, rowNumber);

                    WriteItemObject(row.RowNumber, path, false);
                }
                else
                {
                    ThrowTerminatingInvalidPathException(path);
                }
            } // else
        } // GetChildNames

        /// <summary>
        /// Determines if the specified path has child items.
        /// </summary>
        /// <param name="path">The path to examine.</param>
        /// <returns>
        /// True if the specified path has child items.
        /// </returns>
        protected override bool HasChildItems(string path)
        {
            if (PathIsDrive(path))
            {
                return true;
            }

            return (ChunkPath(path).Length == 1);
        } // HasChildItems

        /// <summary>
        /// Creates a new item at the specified path.
        /// </summary>
        /// 
        /// <param name="path">
        /// The path to the new item.
        /// </param>
        /// 
        /// <param name="type">
        /// Type for the object to create. "Table" for creating a new table and
        /// "Row" for creating a new row in a table.
        /// </param>
        /// 
        /// <param name="newItemValue">
        /// Object for creating new instance of a type at the specified path. For
        /// creating a "Table" the object parameter is ignored and for creating
        /// a "Row" the object must be of type string which will contain comma 
        /// separated values of the rows to insert.
        /// </param>
        protected override void NewItem(string path, string type,
                                    object newItemValue)
        {
            string objectName;
            int rowNumber;

            PathType pt = GetNamesFromPath(path, out objectName, out rowNumber);

            if (pt == PathType.Invalid)
            {
                ThrowTerminatingInvalidPathException(path);
            }

            // Check if type is either "table" or "row", if not throw an 
            // exception
            if (!String.Equals(type, "table", StringComparison.OrdinalIgnoreCase)
                && !String.Equals(type, "row", StringComparison.OrdinalIgnoreCase))
            {
                WriteError(new ErrorRecord
                                  (new ArgumentException("Type must be either a table or row"),
                                      "CannotCreateSpecifiedObject",
                                         ErrorCategory.InvalidArgument,
                                              path
                                   )
                          );

                throw new ArgumentException("This provider can only create items of type \"table\" or \"row\"");
            }

            // Path type is the type of path of the container. So if a drive
            // is specified, then a table can be created under it and if a table
            // is specified, then a row can be created under it. For the sake of 
            // completeness, if a row is specified, then if the row specified by
            // the path does not exist, a new row is created. However, the row 
            // number may not match as the row numbers only get incremented based 
            // on the number of rows

            if (PathIsDrive(path))
            {
                if (String.Equals(type, "table", StringComparison.OrdinalIgnoreCase))
                {
                    // Execute command using ODBC connection to create a table
                    try
                    {
                        // create the table using an sql statement
                        string newobjectName = newItemValue.ToString();
                        string sql = "create table " + newobjectName
                                             + " (ID INT)";

                        // Create the table using the Odbc connection from the 
                        // drive.
                        GoogleCloudStoragePSDriveInfo di = this.PSDriveInfo as GoogleCloudStoragePSDriveInfo;

                        if (di == null)
                        {
                            return;
                        }
                        OdbcConnection connection = di.Connection;

                        if (ShouldProcess(newobjectName, "create"))
                        {
                            OdbcCommand cmd = new OdbcCommand(sql, connection);
                            cmd.ExecuteScalar();
                        }
                    }
                    catch (Exception ex)
                    {
                        WriteError(new ErrorRecord(ex, "CannotCreateSpecifiedTable",
                                  ErrorCategory.InvalidOperation, path)
                                  );
                    }
                } // if (String...
                else if (String.Equals(type, "row", StringComparison.OrdinalIgnoreCase))
                {
                    throw new
                        ArgumentException("A row cannot be created under a database, specify a path that represents a Table");
                }
            }// if (PathIsDrive...
            else
            {
                if (String.Equals(type, "table", StringComparison.OrdinalIgnoreCase))
                {
                    if (rowNumber < 0)
                    {
                        throw new
                            ArgumentException("A table cannot be created within another table, specify a path that represents a database");
                    }
                    else
                    {
                        throw new
                            ArgumentException("A table cannot be created inside a row, specify a path that represents a database");
                    }
                } //if (String.Equals....
                // if path specified is a row, create a new row
                else if (String.Equals(type, "row", StringComparison.OrdinalIgnoreCase))
                {
                    // The user is required to specify the values to be inserted 
                    // into the table in a single string separated by commas
                    string value = newItemValue as string;

                    if (String.IsNullOrEmpty(value))
                    {
                        throw new
                            ArgumentException("Value argument must have comma separated values of each column in a row");
                    }
                    string[] rowValues = value.Split(',');

                    OdbcDataAdapter da = GetAdapterForTable(objectName);

                    if (da == null)
                    {
                        return;
                    }

                    DataSet ds = GetDataSetForTable(da, objectName);
                    DataTable table = GetDataTable(ds, objectName);

                    if (rowValues.Length != table.Columns.Count)
                    {
                        string message = String.Format(CultureInfo.CurrentCulture,
                                            "The table has {0} columns and the value specified must have so many comma separated values",
                                                table.Columns.Count);

                        throw new ArgumentException(message);
                    }

                    if (!Force && (rowNumber >= 0 && rowNumber < table.Rows.Count))
                    {
                        string message = String.Format(CultureInfo.CurrentCulture, 
                                            "The row {0} already exists. To create a new row specify row number as {1}, or specify path to a table, or use the -Force parameter",
                                                rowNumber, table.Rows.Count);

                        throw new ArgumentException(message);
                    }

                    if (rowNumber > table.Rows.Count)
                    {
                        string message = String.Format(CultureInfo.CurrentCulture, 
                                            "To create a new row specify row number as {0}, or specify path to a table",
                                                 table.Rows.Count);

                        throw new ArgumentException(message);
                    }

                    // Create a new row and update the row with the input
                    // provided by the user
                    DataRow row = table.NewRow();
                    for (int i = 0; i < rowValues.Length; i++)
                    {
                        row[i] = rowValues[i];
                    }
                    table.Rows.Add(row);

                    if (ShouldProcess(objectName, "update rows"))
                    {
                        // Update the table from memory back to the data source
                        da.Update(ds, objectName);
                    }

                }// else if (String...
            }// else ...

        } // NewItem

        /// <summary>
        /// Copies an item at the specified path to the location specified
        /// </summary>
        /// 
        /// <param name="path">
        /// Path of the item to copy
        /// </param>
        /// 
        /// <param name="copyPath">
        /// Path of the item to copy to
        /// </param>
        /// 
        /// <param name="recurse">
        /// Tells the provider to recurse subcontainers when copying
        /// </param>
        /// 
        protected override void CopyItem(string path, string copyPath, bool recurse)
        {
            string objectName, copyobjectName;
            int rowNumber, copyRowNumber;

            PathType type = GetNamesFromPath(path, out objectName, out rowNumber);
            PathType copyType = GetNamesFromPath(copyPath, out copyobjectName, out copyRowNumber);

            if (type == PathType.Invalid)
            {
                ThrowTerminatingInvalidPathException(path);
            }

            if (type == PathType.Invalid)
            {
                ThrowTerminatingInvalidPathException(copyPath);
            }

            // Get the table and the table to copy to 
            OdbcDataAdapter da = GetAdapterForTable(objectName);
            if (da == null)
            {
                return;
            }

            DataSet ds = GetDataSetForTable(da, objectName);
            DataTable table = GetDataTable(ds, objectName);

            OdbcDataAdapter cda = GetAdapterForTable(copyobjectName);
            if (cda == null)
            {
                return;
            }

            DataSet cds = GetDataSetForTable(cda, copyobjectName);
            DataTable copyTable = GetDataTable(cds, copyobjectName);

            // if source represents a table
            if (type == PathType.Table)
            {
                // if copyPath does not represent a table
                if (copyType != PathType.Table)
                {
                    ArgumentException e = new ArgumentException("Table can only be copied on to another table location");

                    WriteError(new ErrorRecord(e, "PathNotValid",
                        ErrorCategory.InvalidArgument, copyPath));

                    throw e;
                }

                // if table already exists then force parameter should be set 
                // to force a copy
                if (!Force && GetTable(copyobjectName) != null)
                {
                    throw new ArgumentException("Specified path already exists");
                }

                for (int i = 0; i < table.Rows.Count; i++)
                {
                    DataRow row = table.Rows[i];
                    DataRow copyRow = copyTable.NewRow();

                    copyRow.ItemArray = row.ItemArray;
                    copyTable.Rows.Add(copyRow);
                }
            } // if (type == ...
            // if source represents a row
            else
            {
                if (copyType == PathType.Row)
                {
                    if (!Force && (copyRowNumber < copyTable.Rows.Count))
                    {
                        throw new ArgumentException("Specified path already exists.");
                    }

                    DataRow row = table.Rows[rowNumber];
                    DataRow copyRow = null;

                    if (copyRowNumber < copyTable.Rows.Count)
                    {
                        // copy to an existing row
                        copyRow = copyTable.Rows[copyRowNumber];
                        copyRow.ItemArray = row.ItemArray;
                        copyRow[0] = GetNextID(copyTable);
                    }
                    else if (copyRowNumber == copyTable.Rows.Count)
                    {
                        // copy to the next row in the table that will 
                        // be created
                        copyRow = copyTable.NewRow();
                        copyRow.ItemArray = row.ItemArray;
                        copyRow[0] = GetNextID(copyTable);
                        copyTable.Rows.Add(copyRow);
                    }
                    else
                    {
                        // attempting to copy to a nonexistent row or a row
                        // that cannot be created now - throw an exception
                        string message = String.Format(CultureInfo.CurrentCulture, 
                                            "The item cannot be specified to the copied row. Specify row number as {0}, or specify a path to the table.",
                                                table.Rows.Count);

                        throw new ArgumentException(message);
                    }
                }
                else
                {
                    // destination path specified represents a table, 
                    // create a new row and copy the item
                    DataRow copyRow = copyTable.NewRow();
                    copyRow.ItemArray = table.Rows[rowNumber].ItemArray;
                    copyRow[0] = GetNextID(copyTable);
                    copyTable.Rows.Add(copyRow);
                }
            }

            if (ShouldProcess(copyobjectName, "CopyItems"))
            {
                cda.Update(cds, copyobjectName);
            }

        } //CopyItem

        /// <summary>
        /// Removes (deletes) the item at the specified path
        /// </summary>
        /// 
        /// <param name="path">
        /// The path to the item to remove.
        /// </param>
        /// 
        /// <param name="recurse">
        /// True if all children in a subtree should be removed, false if only
        /// the item at the specified path should be removed. Is applicable
        /// only for container (table) items. Its ignored otherwise (even if
        /// specified).
        /// </param>
        /// 
        /// <remarks>
        /// There are no elements in this store which are hidden from the user.
        /// Hence this method will not check for the presence of the Force
        /// parameter
        /// </remarks>
        /// 
        protected override void RemoveItem(string path, bool recurse)
        {
            string objectName;
            int rowNumber = 0;

            PathType type = GetNamesFromPath(path, out objectName, out rowNumber);

            if (type == PathType.Table)
            {
                // if recurse flag has been specified, delete all the rows as well
                if (recurse)
                {
                    OdbcDataAdapter da = GetAdapterForTable(objectName);
                    if (da == null)
                    {
                        return;
                    }

                    DataSet ds = GetDataSetForTable(da, objectName);
                    DataTable table = GetDataTable(ds, objectName);

                    for (int i = 0; i < table.Rows.Count; i++)
                    {
                        table.Rows[i].Delete();
                    }

                    if (ShouldProcess(path, "RemoveItem"))
                    {
                        da.Update(ds, objectName);
                        RemoveTable(objectName);
                    }
                }//if (recurse...
                else
                {
                    // Remove the table
                    if (ShouldProcess(path, "RemoveItem"))
                    {
                        RemoveTable(objectName);
                    }
                }
            }
            else if (type == PathType.Row)
            {
                OdbcDataAdapter da = GetAdapterForTable(objectName);
                if (da == null)
                {
                    return;
                }

                DataSet ds = GetDataSetForTable(da, objectName);
                DataTable table = GetDataTable(ds, objectName);

                table.Rows[rowNumber].Delete();

                if (ShouldProcess(path, "RemoveItem"))
                {
                    da.Update(ds, objectName);
                }
            }
            else
            {
                ThrowTerminatingInvalidPathException(path);
            }

        } // RemoveItem

        #endregion Container Overloads

       #region Navigation

        /// <summary>
        /// Determine if the path specified is that of a container.
        /// </summary>
        /// <param name="path">The path to check.</param>
        /// <returns>True if the path specifies a container.</returns>
        protected override bool IsItemContainer(string path)
        {
            if (PathIsDrive(path))
            {
                return true;
            }

            string[] pathChunks = ChunkPath(path);
            string objectName;
            int rowNumber;

            PathType type = GetNamesFromPath(path, out objectName, out rowNumber);

            if (type == PathType.Table)
            {
                foreach (DatabaseTableInfo ti in GetTables())
                {
                    if (string.Equals(ti.Name, objectName, StringComparison.OrdinalIgnoreCase))
                    {
                        return true;
                    }
                } // foreach (DatabaseTableInfo...
            } // if (pathChunks...

            return false;
        } // IsItemContainer

        /// <summary>
        /// Get the name of the leaf element in the specified path        
        /// </summary>
        /// 
        /// <param name="path">
        /// The full or partial provider specific path
        /// </param>
        /// 
        /// <returns>
        /// The leaf element in the path
        /// </returns>
        protected override string GetChildName(string path)
        {
            if (PathIsDrive(path))
            {
                return path;
            }

            string objectName;
            int rowNumber;

            PathType type = GetNamesFromPath(path, out objectName, out rowNumber);

            if (type == PathType.Table)
            {
                return objectName;
            }
            else if (type == PathType.Row)
            {
                return rowNumber.ToString(CultureInfo.CurrentCulture);
            }
            else
            {
                ThrowTerminatingInvalidPathException(path);
            }

            return null;
        }

        /// <summary>
        /// Removes the child segment of the path and returns the remaining
        /// parent portion
        /// </summary>
        /// 
        /// <param name="path">
        /// A full or partial provider specific path. The path may be to an
        /// item that may or may not exist.
        /// </param>
        /// 
        /// <param name="root">
        /// The fully qualified path to the root of a drive. This parameter
        /// may be null or empty if a mounted drive is not in use for this
        /// operation.  If this parameter is not null or empty the result
        /// of the method should not be a path to a container that is a
        /// parent or in a different tree than the root.
        /// </param>
        /// 
        /// <returns></returns>

        protected override string GetParentPath(string path, string root)
        {
            // If root is specified then the path has to contain
            // the root. If not nothing should be returned
            if (!String.IsNullOrEmpty(root))
            {
                if (!path.Contains(root))
                {
                    return null;
                }
            }

            return path.Substring(0, path.LastIndexOf(pathSeparator, StringComparison.OrdinalIgnoreCase));
        }

        /// <summary>
        /// Joins two strings with a provider specific path separator.
        /// </summary>
        /// 
        /// <param name="parent">
        /// The parent segment of a path to be joined with the child.
        /// </param>
        /// 
        /// <param name="child">
        /// The child segment of a path to be joined with the parent.
        /// </param>
        /// 
        /// <returns>
        /// A string that represents the parent and child segments of the path
        /// joined by a path separator.
        /// </returns>
/*
        protected override string MakePath(string parent, string child)
        {
            string result;

            string normalParent = NormalizePath(parent);
            normalParent = RemoveDriveFromPath(normalParent);
            string normalChild = NormalizePath(child);
            normalChild = RemoveDriveFromPath(normalChild);

            if (String.IsNullOrEmpty(normalParent) && String.IsNullOrEmpty(normalChild))
            {
                result = String.Empty;
            }
            else if (String.IsNullOrEmpty(normalParent) && !String.IsNullOrEmpty(normalChild))
            {
                result = normalChild;
            }
            else if (!String.IsNullOrEmpty(normalParent) && String.IsNullOrEmpty(normalChild))
            {
                if (normalParent.EndsWith(pathSeparator, StringComparison.OrdinalIgnoreCase))
                {
                    result = normalParent;
                }
                else
                {
                    result = normalParent + pathSeparator;
                }
            } // else if (!String...
            else
            {
                if (!normalParent.Equals(String.Empty, StringComparison.OrdinalIgnoreCase) && 
                    !normalParent.EndsWith(pathSeparator, StringComparison.OrdinalIgnoreCase))
                {
                    result = normalParent + pathSeparator;
                }
                else
                {
                    result = normalParent;
                }

                if (normalChild.StartsWith(pathSeparator, StringComparison.OrdinalIgnoreCase))
                {
                    result += normalChild.Substring(1);
                }
                else
                {
                    result += normalChild;
                }
            } // else

            return result;
        } // MakePath

        /// <summary>
        /// Normalizes the path that was passed in and returns the normalized
        /// path as a relative path to the basePath that was passed.
        /// </summary>
        /// 
        /// <param name="path">
        /// A fully qualified provider specific path to an item.  The item
        /// should exist or the provider should write out an error.
        /// </param>
        /// 
        /// <param name="basepath">
        /// The path that the return value should be relative to.
        /// </param>
        /// 
        /// <returns>
        /// A normalized path that is relative to the basePath that was
        /// passed.  The provider should parse the path parameter, normalize
        /// the path, and then return the normalized path relative to the
        /// basePath.
        /// </returns>

        protected override string NormalizeRelativePath(string path,
                                                             string basepath)
        {
            // Normalize the paths first
            string normalPath = NormalizePath(path);
            normalPath = RemoveDriveFromPath(normalPath);
            string normalBasePath = NormalizePath(basepath);
            normalBasePath = RemoveDriveFromPath(normalBasePath);

            if (String.IsNullOrEmpty(normalBasePath))
            {
                return normalPath;
            }
            else
            {
                if (!normalPath.Contains(normalBasePath))
                {
                    return null;
                }

                return normalPath.Substring(normalBasePath.Length + pathSeparator.Length);
            }
        }

        /// <summary>
        /// Moves the item specified by the path to the specified destination
        /// </summary>
        /// 
        /// <param name="path">
        /// The path to the item to be moved
        /// </param>
        /// 
        /// <param name="destination">
        /// The path of the destination container
        /// </param>
*/
        protected override void MoveItem(string path, string destination)
        {
            // Get type, table name and rowNumber from the path
            string objectName, destobjectName;
            int rowNumber, destRowNumber;

            PathType type = GetNamesFromPath(path, out objectName, out rowNumber);

            PathType destType = GetNamesFromPath(destination, out destobjectName,
                                     out destRowNumber);

            if (type == PathType.Invalid)
            {
                ThrowTerminatingInvalidPathException(path);
            }

            if (destType == PathType.Invalid)
            {
                ThrowTerminatingInvalidPathException(destination);
            }

            if (type == PathType.Table)
            {
                ArgumentException e = new ArgumentException("Move not supported for tables");

                WriteError(new ErrorRecord(e, "MoveNotSupported",
                    ErrorCategory.InvalidArgument, path));

                throw e;
            }
            else
            {
                OdbcDataAdapter da = GetAdapterForTable(objectName);
                if (da == null)
                {
                    return;
                }

                DataSet ds = GetDataSetForTable(da, objectName);
                DataTable table = GetDataTable(ds, objectName);

                OdbcDataAdapter dda = GetAdapterForTable(destobjectName);
                if (dda == null)
                {
                    return;
                }

                DataSet dds = GetDataSetForTable(dda, destobjectName);
                DataTable destTable = GetDataTable(dds, destobjectName);
                DataRow row = table.Rows[rowNumber];

                if (destType == PathType.Table)
                {
                    DataRow destRow = destTable.NewRow();

                    destRow.ItemArray = row.ItemArray;
                }
                else
                {
                    DataRow destRow = destTable.Rows[destRowNumber];

                    destRow.ItemArray = row.ItemArray;
                }

                // Update the changes
                if (ShouldProcess(path, "MoveItem"))
                {
                    WriteItemObject(row, path, false);
                    dda.Update(dds, destobjectName);
                }
            }
        }

        #endregion Navigation

       #region Helper Methods

        /// <summary>
        /// Checks if a given path is actually a drive name.
        /// </summary>
        /// <param name="path">The path to check.</param>
        /// <returns>
        /// True if the path given represents a drive, false otherwise.
        /// </returns>
        private bool PathIsDrive(string path)
        {
            // Remove the drive name and first path separator.  If the 
            // path is reduced to nothing, it is a drive. Also if its
            // just a drive then there wont be any path separators
            if (
                String.IsNullOrEmpty(
                        path.Replace(this.PSDriveInfo.Root, ""))
                ||
                String.IsNullOrEmpty(
                        path.Replace(this.PSDriveInfo.Root + pathSeparator, ""))
               )
            {
                return true;
            }
            else
            {
                return false;
            }
        } // PathIsDrive

        /// <summary>
        /// Breaks up the path into individual elements.
        /// </summary>
        /// <param name="path">The path to split.</param>
        /// <returns>An array of path segments.</returns>
        private string[] ChunkPath(string path)
        {
            // Normalize the path before splitting
            string normalPath = NormalizePath(path);

            // Return the path with the drive name and first path 
            // separator character removed, split by the path separator.
            string pathNoDrive = normalPath.Replace(this.PSDriveInfo.Root
                                           + pathSeparator, "");

            return pathNoDrive.Split(pathSeparator.ToCharArray());
        } // ChunkPath

        /// <summary>
        /// Adapts the path, making sure the correct path separator
        /// character is used.
        /// </summary>
        /// <param name="path"></param>
        /// <returns></returns>
        private string NormalizePath(string path)
        {
            string result = path;

            if (!String.IsNullOrEmpty(path))
            {
                result = path.Replace("\\", pathSeparator);
            }

            return result;
        } // NormalizePath

        /// <summary>
        /// Ensures that the drive is removed from the specified path
        /// </summary>
        /// 
        /// <param name="path">Path from which drive needs to be removed</param>
        /// <returns>Path with drive information removed</returns>
        private string RemoveDriveFromPath(string path)
        {
            string root;

            if (this.PSDriveInfo == null)
            {
                root = String.Empty;
            }
            else
            {
                root = this.PSDriveInfo.Root;
            }

            if (path == null)
            {
                return String.Empty;
            }

            if (path.Contains(root))
            {
                return path.Substring(path.IndexOf(root, StringComparison.OrdinalIgnoreCase) + root.Length);
            }

            return path;
        }

        /// <summary>
        /// Chunks the path and returns the table name and the row number 
        /// from the path
        /// </summary>
        /// <param name="path">Path to chunk and obtain information</param>
        /// <returns>GcsPath</returns>
        public GcsPath GetGcsPath(string path)
        {
            PathType retVal = PathType.Invalid;
            var gcsPath = new GcsPath;

            // chunk the path into parts
            string[] pathChunks = ChunkPath(path);

            switch (pathChunks.Length)
            {
                case 1:
                    {
                        gcsPath.BucketName = pathChunks[0];
                    }
                    break;
                case > 1:
                    {
                        gcsPath.BucketName = pathChunks[0];
                        gcsPath.ObjectPath = String.Join("/", pathChunks[1..(pathChunks.Length - 1)])
                    }

                default:
                    {
                        WriteError(new ErrorRecord(
                            new ArgumentException("The path supplied has too many segments"),
                            "PathNotValid",
                            ErrorCategory.InvalidArgument,
                            path));
                        ThrowTerminatingInvalidPathException(path);
                    }
                    break;
            }

            return gcsPath;
        }

        /// <summary>
        /// Throws an argument exception stating that the specified path does
        /// not represent either a table or a row
        /// </summary>
        /// <param name="path">path which is invalid</param>
        private void ThrowTerminatingInvalidPathException(string path)
        {
            StringBuilder message = new StringBuilder("Path must include at least a bucket");
            message.Append(path);

            throw new ArgumentException(message.ToString());
        }

        /// <summary>
        /// Removes the specified table from the database
        /// </summary>
        /// <param name="objectName">Name of the table to remove</param>
        private void RemoveObject(string objectName)
        {
            // validate if objectName is valid and if table is present
            if (String.IsNullOrEmpty(objectName) || !ObjectNameIsValid(objectName) || !TableIsPresent(objectName))
            {
                return;
            }

            // Execute command using ODBC connection to remove a table
            try
            {
                // delete the table using an sql statement
                string sql = "drop table " + objectName;

                GoogleCloudStoragePSDriveInfo di = this.PSDriveInfo as GoogleCloudStoragePSDriveInfo;

                if (di == null)
                {
                    return;
                }
                OdbcConnection connection = di.Connection;

                OdbcCommand cmd = new OdbcCommand(sql, connection);
                cmd.ExecuteScalar();
            }
            catch (Exception ex)
            {
                WriteError(new ErrorRecord(ex, "CannotRemoveSpecifiedTable",
                          ErrorCategory.InvalidOperation, null)
                          );
            }

        } // RemoveTable

       private bool ObjectNameIsValid(string objectName)
       {
           Regex exp = new Regex(pattern, RegexOptions.Compiled | RegexOptions.IgnoreCase);

           if (exp.IsMatch(objectName))
           {
               return true;
           }
           WriteError(new ErrorRecord(
               new ArgumentException("Table name not valid"), "objectNameNotValid",
                   ErrorCategory.InvalidArgument, objectName));
           return false;
       } // ObjectNameIsValid

       /// <summary>
       /// Checks to see if the specified table is present in the
       /// database
       /// </summary>
       /// <param name="objectName">Name of the table to check</param>
       /// <returns>true, if table is present, false otherwise</returns>
       private bool ObjectIsPresent(string objectName)
       {
           // using ODBC connection to the database and get the schema of tables
           GoogleCloudStoragePSDriveInfo di = this.PSDriveInfo as GoogleCloudStoragePSDriveInfo;
           if (di == null)
           {
               return false;
           }

           StorageClient client = di.GcsClient;
           var gcsObject = client.GetObject(di.BucketUrl, objectName);

            if ( ! String.IsNullOrEmpty(gcsObject.Id))
            {
                return true;
            }

           WriteError(new ErrorRecord(
               new ArgumentException($"Specified object {objectName} in bucket is not present in database"), "TableNotAvailable",
                    ErrorCategory.InvalidArgument, objectName));

           return false;
       }// TableIsPresent

       /// <summary>
       /// Get an object used to write content.
       /// </summary>
       /// <param name="path">The root path at which to write.</param>
       /// <returns>A content writer for writing.</returns>
       public IContentWriter GetContentWriter(string path)
       {
           string objectName;
           int rowNumber;

           PathType type = GetNamesFromPath(path, out objectName, out rowNumber);

           if (type == PathType.Invalid)
           {
               ThrowTerminatingInvalidPathException(path);
           }
           else if (type == PathType.Row)
           {
               throw new InvalidOperationException("contents can be added only to tables");
           }

           return new GoogleCloudStorageContentWriter(path, this);
       }

       /// <summary>
       /// Not implemented.
       /// </summary>
       /// <param name="path"></param>
       /// <returns></returns>
       public object GetContentWriterDynamicParameters(string path)
       {
           return null;
       }

       #endregion Content Methods
    } // GoogleCloudStorageProvider

    #endregion GoogleCloudStorageProvider

    #region Public Enumerations

    /// <summary>
    /// Type of item represented by the path
    /// </summary>
    public enum PathType
    {
       /// <summary>
       /// Represents a table
       /// </summary>
       Table,
       /// <summary>
       /// Represents a row
       /// </summary>
       Row,
       /// <summary>
       /// Represents an invalid path
       /// </summary>
       Invalid
    };

    #endregion Public Enumerations

    #region GoogleCloudStoragePSDriveInfo

    /// <summary>
    /// Any state associated with the drive should be held here.
    /// In this case, it's the connection to the GCS bucket.
    /// </summary>
    internal class GoogleCloudStoragePSDriveInfo : PSDriveInfo
    {

        /// <summary>
        /// Google Cloud Storage client information.
        /// </summary>
        public StorageClient GcsClient
        {
            get { return GcsClient; }
            set { GcsClient = value; }
        }

        public String ProjectId
        {
            get { return ProjectId; }
            set { ProjectId = value; }
        }

        /// <summary>
        /// Constructor that takes one argument
        /// </summary>
        /// <param name="driveInfo">Drive provided by this provider</param>
        public GoogleCloudStoragePSDriveInfo(PSDriveInfo driveInfo)
            : base(driveInfo)
        {
            this.GcsClient = StorageClient.Create();
        }

    } // class GoogleCloudStoragePSDriveInfo

    #endregion GoogleCloudStoragePSDriveInfo

    internal class GcsPath {
        public string BucketName
        {
            get { return BucketName; }
            set { BucketName = value; }
        }
        public string ObjectPath
        {
            get { return ObjectPath; }
            set { ObjectPath = value; }
        }
    }

}