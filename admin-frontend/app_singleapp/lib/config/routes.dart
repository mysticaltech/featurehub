import 'package:app_singleapp/api/client_api.dart';
import 'package:app_singleapp/api/router.dart';
import 'package:bloc_provider/bloc_provider.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

import 'route_handlers.dart';

final _log = Logger('Routes');

class Routes {
  static final List<String> PUBLIC_URLS = ['/forgot-password', '/register-url'];
  static void configureRoutes(FHRouter router) {
    router.notFoundHandler = Handler(
        handlerFunc: (BuildContext context, Map<String, List<String>> params) {
      _log.severe('request for route not found');
      var mrBloc = BlocProvider.of<ManagementRepositoryClientBloc>(context);
      mrBloc.customError(messageTitle: 'Oops, page not found');
      return Container();
    });

    // Public routes (public URL's also need ot be added to array above)
    router.define('/forgot-password',
        handler: handleRouteChangeRequest(forgotPassword),
        transitionType: TransitionType.fadeIn);
    router.define('/register-url',
        handler: handleRouteChangeRequest(registerUrl),
        transitionType: TransitionType.fadeIn);

    // main app routes
    router.define('/',
        handler: handleRouteChangeRequest(root),
        transitionType: TransitionType.fadeIn);
    router.define('',
        handler: handleRouteChangeRequest(root),
        transitionType: TransitionType.fadeIn);
    router.define('/applications',
        handler: handleRouteChangeRequest(apps),
        transitionType: TransitionType.fadeIn);
    router.define('/feature-status',
        handler: handleRouteChangeRequest(featureStatus),
        transitionType: TransitionType.fadeIn);
    router.define('/feature-values',
        handler: handleRouteChangeRequest(featureValues),
        transitionType: TransitionType.fadeIn);

    router.define('/service-envs',
        handler: handleRouteChangeRequest(serviceEnvsHandler));

    //Admin routes
    router.define('/create-user',
        handler: handleRouteChangeRequest(createUser),
        permissionType: PermissionType.portfolioadmin,
        transitionType: TransitionType.fadeIn);
    router.define('/portfolios',
        handler: handleRouteChangeRequest(portfolios),
        transitionType: TransitionType.material);
    router.define('/manage-app',
        handler: handleRouteChangeRequest(manageApp),
        permissionType: PermissionType.portfolioadmin,
        transitionType: TransitionType.fadeIn);
    router.define('/manage-group',
        handler: handleRouteChangeRequest(group),
        permissionType: PermissionType.portfolioadmin,
        transitionType: TransitionType.fadeIn);
    router.define('/manage-service-accounts',
        handler: handleRouteChangeRequest(serviceAccount),
        permissionType: PermissionType.portfolioadmin,
        transitionType: TransitionType.fadeIn);
    router.define('/manage-user',
        handler: handleRouteChangeRequest(manageUser),
        permissionType: PermissionType.portfolioadmin,
        transitionType: TransitionType.fadeIn);
    router.define('/manage-users',
        handler: handleRouteChangeRequest(users),
        permissionType: PermissionType.portfolioadmin,
        transitionType: TransitionType.fadeIn);
  }
}
