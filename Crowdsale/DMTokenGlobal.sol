pragma solidity ^0.4.21;

import "zeppelin-solidity/contracts/math/SafeMath.sol";
import "zeppelin-solidity/contracts/lifecycle/Pausable.sol";

/*
 * Токен для Imaguru Blockchain Hackathon
 * DebtMoneyToken  - используется для токенизации задолженностей на предприятии
 */
 contract DMTokenGlobal is Pausable {

 	using SafeMath for uint256;

 	address public serverAddress;
 	address public adminAddress;

 	// Идентификатор компании-владельца контракта
 	bytes32 public constant owner_id = "LLC Credit Chain";

 	event DebetLoanAdded(bytes32 indexed _from, bytes32 indexed _to, uint256 indexed _amount);
 	event CreditLoanAdded(bytes32 indexed _from, bytes32 indexed _to, uint256 indexed _amount);
 	event DebetLoanBurned(bytes32[] _companies, uint256 _amount);
 	event CreditLoanBurned(bytes32[] _companies, uint256 _amount);

 	modifier onlyServer() {
 		require(msg.sender == serverAddress);
 		_;
 	}

 	modifier onlyAdmin() {
 		require(msg.sender == adminAddress);
 		_;
 	}

 	// Маппинг дебеторских задолженностей
 	mapping (bytes32 => mapping (bytes32 => uint256)) debetLoan;
 	// Маппинг кредиторских задолженностей
 	mapping (bytes32 => mapping (bytes32 => uint256)) creditLoan;

 	/**
 	 * Добавляет новую дебеторскую задолженность
 	 * @param _from Налоговый идентификатор компании
 	 * @param _to Налоговый идентификатор должника
 	 * @param _amount Сумма задолженности
 	 */
 	function addDebetLoan(bytes32 _from, bytes32 _to, uint256 _amount) public onlyServer whenNotPaused {
 		require(_amount != 0);
 		require(!isExistsDebet(_from, _to));
 		debetLoan[_from][_to] = _amount;
 		emit DebetLoanAdded(_from, _to, _amount);
 	}

 	/**
 	 * Добавляет новую кредиторскую задолженность
 	 * Дополнительно добавляется задолженность перед нами в размере 1 процента от суммы кредиторской задолженности
 	 * @param _from Налоговый идентификатор компании
 	 * @param _to Налоговый идентификатор должника
 	 * @param _amount Сумма задолженности
 	 */
 	function addCreditLoan(bytes32 _from, bytes32 _to, uint256 _amount) public onlyServer whenNotPaused {
 		require(_amount != 0);
 		require(!isExistsCredit(_from, _to));
 		creditLoan[_from][_to] = _amount;
 		creditLoan[_from][owner_id] = _amount / 100;
 		emit CreditLoanAdded(_from, _to, _amount);
 	}

 	function setServerAddress(address _server) public onlyAdmin {
 		require(_server != address(0));
 		serverAddress = _server;
 	}

 	function transferAdminship(address _to) public onlyAdmin {
 		require(_to != address(0));
 		adminAddress = _to;
 	}

 	function getDebetLoanAmount(bytes32 _from, bytes32 _to) public view returns (uint256) {
 		return debetLoan[_from][_to];
 	}

 	function getCreditLoanAmount(bytes32 _from, bytes32 _to) public view returns (uint256) {
 		return creditLoan[_from][_to];
 	}
 	
 	/**
 	 *	Проверяет существование такого долга. Если у цепочки нулевая задолженность, то она не существует
 	 */
 	function isExistsDebet(bytes32 _from, bytes32 _to) internal view returns (bool) {
 		return debetLoan[_from][_to] != 0;
 	}

 	/**
 	 *	Проверяет существование такого долга. Если у цепочки нулевая задолженность, то она не существует
 	 */
 	function isExistsCredit(bytes32 _from, bytes32 _to) internal view returns (bool) {
 		return creditLoan[_from][_to] != 0;
 	}

 	/**
 	 *	Очищает цепочку дебиторских задолженностей
 	 *  Количество элементов входного массива ограничено 10 элементами
 	 *  @param _from Массив идентификаторов компаний, с которых нужно списать дебетовый долг
 	 *  @param _to Массив идентификаторов компаний, в пользу которых списывается долг
 	 *  @param _amount Сумма к списанию
 	 */
 	function burnDebitLoan(bytes32[] _from, bytes32[] _to, uint256 _amount) public onlyServer whenNotPaused {
 		uint len = _from.length;
 		require(len <= 10);

 		for (uint i = 0; i < len; i++) {
 			debetLoan[_from[i]][_to[i]].sub(_amount);
 		}

 		emit DebetLoanBurned(_from, _amount);
 	}

 	/**
 	 *	Очищает цепочку кредиторских задолженностей
 	 *  Количество элементов входного массива ограничено 10 элементами
 	 *  @param _from Массив идентификаторов компаний, с которых нужно списать кредиторский долг
 	 *  @param _to Массив идентификаторов компаний, в пользу которых списывается долг
 	 *  @param _amount Сумма к списанию 
 	 */
 	function burnCreditLoan(bytes32[] _from, bytes32[] _to, uint256 _amount) public onlyServer whenNotPaused {
 		uint len = _from.length;
 		require(len <= 10);

 		for (uint i = 0; i < len; i++) {
 			creditLoan[_from[i]][_to[i]].sub(_amount);
 		}

 		emit CreditLoanBurned(_from, _amount);
 	}
}