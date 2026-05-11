import { render } from '@testing-library/react';
import DashboardHome from './DashboardHome';

test('renders dashboard component without crashing', () => {
    render(<DashboardHome />);
});