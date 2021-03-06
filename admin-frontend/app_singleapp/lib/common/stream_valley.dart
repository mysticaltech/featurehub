import 'dart:async';

import 'package:app_singleapp/api/client_api.dart';
import 'package:app_singleapp/common/person_state.dart';
import 'package:logging/logging.dart';
import 'package:mrapi/api.dart';
import 'package:rxdart/rxdart.dart';

class ReleasedPortfolio {
  Portfolio portfolio;
  bool currentPortfolioOrSuperAdmin;
}

typedef findApplicationsFunc = Future<List<Application>> Function(
    String portfolioId);

final _log = Logger('stream-valley');

class StreamValley {
  final ManagementRepositoryClientBloc mrClient;
  final PersonState personState;
  AuthServiceApi authServiceApi;
  PortfolioServiceApi portfolioServiceApi;
  ServiceAccountServiceApi serviceAccountServiceApi;
  EnvironmentServiceApi environmentServiceApi;
  FeatureServiceApi featureServiceApi;
  ApplicationServiceApi applicationServiceApi;

  StreamSubscription<ReleasedPortfolio>
      currentPortfolioAdminOrSuperAdminSubscription;
  StreamSubscription<Portfolio> currentPortfolioSubscription;

  bool _isCurrentPortfolioAdminOrSuperAdmin = false;

  StreamValley(this.mrClient, this.personState) {
    authServiceApi = AuthServiceApi(mrClient.apiClient);
    portfolioServiceApi = PortfolioServiceApi(mrClient.apiClient);
    serviceAccountServiceApi = ServiceAccountServiceApi(mrClient.apiClient);
    environmentServiceApi = EnvironmentServiceApi(mrClient.apiClient);
    featureServiceApi = FeatureServiceApi(mrClient.apiClient);
    applicationServiceApi = ApplicationServiceApi(mrClient.apiClient);

    // release the route check portfolio into the main stream so downstream stuff can trigger as usual.
    // we  have done our permission checks on it and swapped their route if they have no access
    currentPortfolioAdminOrSuperAdminSubscription =
        personState.isCurrentPortfolioOrSuperAdmin.listen((val) {
      _currentPortfolioSource.add(val.portfolio);
      _isCurrentPortfolioAdminOrSuperAdmin = val.currentPortfolioOrSuperAdmin;
      _refreshApplicationIdChanged();
      if (_isCurrentPortfolioAdminOrSuperAdmin) {
        getCurrentPortfolioGroups();
        getCurrentPortfolioServiceAccounts();
      } else {
        currentPortfolioGroups = [];
        currentPortfolioServiceAccounts = [];
        _lastPortfolioIdServiceAccountChecked = null;
        _lastPortfolioIdGroupChecked = null;
      }
    });

    currentPortfolioSubscription =
        _currentPortfolioSource.listen((p) => portfolioChanged());
  }

  void dispose() {
    currentPortfolioSubscription.cancel();
    currentPortfolioAdminOrSuperAdminSubscription.cancel();
  }

  void portfolioChanged() {
    // now load the applications for this portfolio, which may trigger selecting one
    getCurrentPortfolioApplications();

    // if we are an admin, load the groups and service accounts
//    if (_isCurrentPortfolioAdminOrSuperAdmin) {
//      getCurrentPortfolioGroups();
//      getCurrentPortfolioServiceAccounts();
//    }
  }

  void _refreshApplicationIdChanged() {
    if (_isCurrentPortfolioAdminOrSuperAdmin &&
        _currentAppIdSource.value != null) {
      getCurrentApplicationFeatures();
      getCurrentApplicationEnvironments();
    }
  }

  final _portfoliosSource = BehaviorSubject<List<Portfolio>>();
  final _currentPortfolioSource = BehaviorSubject<Portfolio>();
  final _routeCheckPortfolioSource = BehaviorSubject<Portfolio>();

  final _currentAppIdSource = BehaviorSubject<String>();
  final _currentPortfolioApplicationsSource =
      BehaviorSubject<List<Application>>();
  final _currentPortfolioGroupsStream = BehaviorSubject<List<Group>>();
  final _currentApplicationEnvironmentsSource =
      BehaviorSubject<List<Environment>>();
  final _currentApplicationFeaturesSource = BehaviorSubject<List<Feature>>();
  final _currentEnvironmentServiceAccountSource =
      BehaviorSubject<List<ServiceAccount>>();

  Stream<Portfolio> get routeCheckPortfolioStream => _routeCheckPortfolioSource;
  Stream<List<Portfolio>> get portfolioListStream => _portfoliosSource.stream;
  Stream<Portfolio> get currentPortfolioStream =>
      _currentPortfolioSource.stream;
  Portfolio get currentPortfolio => _currentPortfolioSource.value;

  String get currentPortfolioId => currentPortfolio?.id;

  set currentPortfolioId(String value) {
    _log.fine('Attempting to set portfolio at $value');
    if (value != null && _currentPortfolioSource.value?.id != value) {
      _log.fine('Accepted portfolio id change, triggering');
      currentAppId = null;

      // figure out which one we are
      _routeCheckPortfolioSource.add(
          _portfoliosSource.value.firstWhere((element) => element.id == value));
    } else if (value == null) {
      _log.fine('Portfolio request was null, storing null.');
      _routeCheckPortfolioSource.add(null); // no portfolio
    } else {
      _log.fine('Ignoring portfolio change request');
    }
  }

  Stream<String> get currentPortfolioIdStream =>
      _currentPortfolioSource.stream.map((p) => p?.id);

  Stream<String> get currentAppIdStream => _currentAppIdSource.stream;

  String get currentAppId => _currentAppIdSource.value;

  set currentAppId(String value) {
    _currentAppIdSource.add(value);
    _refreshApplicationIdChanged();
  }

  Stream<List<Application>> get currentPortfolioApplicationsStream =>
      _currentPortfolioApplicationsSource.stream;

  set currentPortfolioApplications(List<Application> value) {
    _currentPortfolioApplicationsSource.add(value);
  }

  Stream<List<Group>> get currentPortfolioGroupsStream =>
      _currentPortfolioGroupsStream.stream;

  set currentPortfolioGroups(List<Group> value) {
    _currentPortfolioGroupsStream.add(value);
  }

  final _currentPortfolioServiceAccountsSource =
      BehaviorSubject<List<ServiceAccount>>();

  Stream<List<ServiceAccount>> get currentPortfolioServiceAccountsStream =>
      _currentPortfolioServiceAccountsSource.stream;

  set currentPortfolioServiceAccounts(List<ServiceAccount> value) {
    _currentPortfolioServiceAccountsSource.add(value);
  }

  Stream<List<Environment>> get currentApplicationEnvironmentsStream =>
      _currentApplicationEnvironmentsSource;

  set currentApplicationEnvironments(List<Environment> value) {
    _currentApplicationEnvironmentsSource.add(value);
  }

  Stream<List<Feature>> get currentApplicationFeaturesStream =>
      _currentApplicationFeaturesSource;

  set currentApplicationFeatures(List<Feature> value) {
    _currentApplicationFeaturesSource.add(value);
  }

  Stream<List<ServiceAccount>> get currentEnvironmentServiceAccountStream =>
      _currentEnvironmentServiceAccountSource;

  set currentEnvironmentServiceAccount(List<ServiceAccount> value) {
    _currentEnvironmentServiceAccountSource.add(value);
  }

  bool _includeEnvironmentsInApplicationRequest = false;

  set includeEnvironmentsInApplicationRequest(bool include) {
    // swapping from false to true
    if (_includeEnvironmentsInApplicationRequest != include && include) {
      _includeEnvironmentsInApplicationRequest = include;
      getCurrentPortfolioApplications();
    }
  }

  Future<void> getCurrentPortfolioApplications(
      {findApplicationsFunc findApp}) async {
    List<Application> appList;
    if (currentPortfolioId != null) {
      if (findApp != null) {
        appList =
            await findApp(currentPortfolioId).catchError(mrClient.dialogError);
      } else {
        appList = await applicationServiceApi
            .findApplications(currentPortfolioId,
                order: SortOrder.DESC,
                includeEnvironments: true,
                includeFeatures: _includeEnvironmentsInApplicationRequest)
            .catchError(mrClient.dialogError);
      }

      currentPortfolioApplications = appList;

      // we refreshed the apps, is the current app id in the list anymore? if not
      // we may have changed portfolios or deleted the app
      if (!appList.map((a) => a.id).contains(currentAppId)) {
        if (appList.isNotEmpty) {
          currentAppId = appList[0].id;
        } else {
          currentAppId = null;
        }
      }
    } else {
      currentPortfolioApplications = [];
    }
  }

  String _lastPortfolioIdGroupChecked;
  Future<List<Group>> getCurrentPortfolioGroups({bool force = false}) async {
    if (currentPortfolioId != _lastPortfolioIdGroupChecked ||
        _lastPortfolioIdGroupChecked == null ||
        force) {
      _lastPortfolioIdGroupChecked = currentPortfolioId;
      if (currentPortfolioId != null) {
        await portfolioServiceApi
            .getPortfolio(currentPortfolioId, includeGroups: true)
            .then((portfolio) => currentPortfolioGroups = portfolio.groups)
            .catchError(mrClient.dialogError);
      } else {
        currentPortfolioGroups = [];
      }
    }

    return _currentPortfolioGroupsStream.value;
  }

  String _lastPortfolioIdServiceAccountChecked;
  Future<void> getCurrentPortfolioServiceAccounts({bool force = false}) async {
    if (currentPortfolioId != _lastPortfolioIdServiceAccountChecked ||
        _lastPortfolioIdServiceAccountChecked == null ||
        force) {
      _lastPortfolioIdServiceAccountChecked = currentPortfolioId;

      if (currentPortfolioId != null) {
        await serviceAccountServiceApi
            .searchServiceAccountsInPortfolio(currentPortfolioId)
            .then((accounts) => currentPortfolioServiceAccounts = accounts)
            .catchError(mrClient.dialogError);
      } else {
        currentPortfolioServiceAccounts = [];
      }
    }
  }

  Future<List<Environment>> getCurrentApplicationEnvironments() async {
    var envList = <Environment>[];

    if (_currentAppIdSource.value != null) {
      envList = await environmentServiceApi
          .findEnvironments(_currentAppIdSource.value, includeAcls: true)
          .catchError(mrClient.dialogError);
    }

    currentApplicationEnvironments = envList;
    return envList;
  }

  Future<void> getCurrentApplicationFeatures() async {
    if (_currentAppIdSource.value != null) {
      final featureList = await featureServiceApi
          .getAllFeaturesForApplication(_currentAppIdSource.value)
          .catchError(mrClient.dialogError);
      currentApplicationFeatures = featureList;
    } else {
      currentApplicationFeatures = [];
    }
  }

  Future<void> getEnvironmentServiceAccountPermissions() async {
    if (_currentAppIdSource.value != null) {
      final saList = await serviceAccountServiceApi
          .searchServiceAccountsInPortfolio(currentPortfolioId,
              includePermissions: true,
              applicationId: _currentAppIdSource.value)
          .catchError(mrClient.dialogError);
      currentEnvironmentServiceAccount = saList;
    } else {
      currentEnvironmentServiceAccount = [];
    }
  }

  Future<List<Portfolio>> loadPortfolios() async {
    final portfolios = await portfolioServiceApi.findPortfolios(
        includeApplications: true, order: SortOrder.ASC);

    _portfoliosSource.add(portfolios);

    if (portfolios.isEmpty) {
      currentPortfolioId = null;
    }

    return portfolios;
  }

  bool containsPid(String pid) {
    return _portfoliosSource.value?.any((p) => p.id == pid);
  }
}
