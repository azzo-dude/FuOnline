using System;
using System.Net.Http;
using System.Text.RegularExpressions;
using System.Threading.Tasks;
using System.Security;
using System.Runtime.InteropServices;
using System.Collections.Generic;
using System.IO;

public class XenoForoV14
{
    private static readonly HttpClient client = new HttpClient
    {
        Timeout = TimeSpan.FromSeconds(30)
    };
    private static readonly Regex xfTokenRegex = new Regex(@"name=""_xfToken""\s+value=""([^""]+)""", RegexOptions.Compiled);
    private const int MaxRetries = 1;
    private const string LogFilePath = @"C:\Users\Azzo\Documents\PowerShell Script\login_log.txt";

    static XenoForoV14()
    {
        client.DefaultRequestHeaders.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/117.0.0.0 Safari/537.36");
    }

    public static async Task<bool> LoginAsync(string username, SecureString password, string url)
    {
        for (int attempt = 0; attempt < MaxRetries; attempt++)
        {
            try
            {
                ResetCookies();
                IntPtr bstr = Marshal.SecureStringToBSTR(password);
                string plainPassword = Marshal.PtrToStringBSTR(bstr);
                Marshal.ZeroFreeBSTR(bstr);

                using (HttpResponseMessage loginPageResponse = await client.GetAsync(url).ConfigureAwait(false))
                {
                    if (!loginPageResponse.IsSuccessStatusCode)
                    {
                        string error = $"Attempt {attempt + 1}: Failed to fetch login page. Status: {loginPageResponse.StatusCode}";
                        File.AppendAllText(LogFilePath, error + Environment.NewLine);
                        if (attempt < MaxRetries - 1) continue;
                        return false;
                    }
                    string loginPageContent = await loginPageResponse.Content.ReadAsStringAsync().ConfigureAwait(false);

                    Match tokenMatch = xfTokenRegex.Match(loginPageContent);
                    if (!tokenMatch.Success)
                    {
                        string error = $"Attempt {attempt + 1}: Could not find _xfToken on the login page.";
                        File.AppendAllText(LogFilePath, error + Environment.NewLine);
                        return false;
                    }
                    string xfToken = tokenMatch.Groups[1].Value;

                    var credentials = new FormUrlEncodedContent(new[]
                    {
                        new KeyValuePair<string, string>("login", username),
                        new KeyValuePair<string, string>("password", plainPassword),
                        new KeyValuePair<string, string>("_xfToken", xfToken)
                    });

                    string loginActionUrl = $"{url}/login";

                    using (HttpResponseMessage response = await client.PostAsync(loginActionUrl, credentials).ConfigureAwait(false))
                    {
                        if (response.IsSuccessStatusCode || (response.StatusCode >= System.Net.HttpStatusCode.Moved && response.StatusCode <= System.Net.HttpStatusCode.PermanentRedirect))
                        {
                            string success = $"Attempt {attempt + 1}: Login successful! Status: {response.StatusCode}";
                            File.AppendAllText(LogFilePath, success + Environment.NewLine);
                            return true;
                        }
                        else
                        {
                            string error = $"Attempt {attempt + 1}: Login failed. Status: {response.StatusCode}";
                            File.AppendAllText(LogFilePath, error + Environment.NewLine);
                            if (attempt < MaxRetries - 1) continue;
                            return false;
                        }
                    }
                }
            }
            catch (HttpRequestException ex)
            {
                string error = $"Attempt {attempt + 1}: HTTP error during login: {ex.Message}";
                File.AppendAllText(LogFilePath, error + Environment.NewLine);
                if (attempt < MaxRetries - 1) continue;
                return false;
            }
            catch (Exception ex)
            {
                string error = $"Attempt {attempt + 1}: Unexpected error during login: {ex.Message}";
                File.AppendAllText(LogFilePath, error + Environment.NewLine);
                return false;
            }
        }
        return false;
    }

    public static void ResetCookies()
    {
        client.DefaultRequestHeaders.Clear();
        client.DefaultRequestHeaders.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/117.0.0.0 Safari/537.36");
    }
}
